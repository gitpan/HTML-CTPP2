/*-
 * Copyright (c) 2006 - 2008 CTPP Team
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 4. Neither the name of the CTPP Team nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *      CTPP2.xs
 *
 * $CTPP$
 */
#include <CTPP2.hpp>

#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#ifdef __cplusplus
}
#endif

// FWD
class Bytecode;

//
// CTPP2 main object
//
class CTPP2
{
public:
	// Constructor
	CTPP2();
	// Destructor
	~CTPP2() throw();

	// Emit parameters
	int param(SV * pParams);

	// Reset parameters
	int reset();

	// Reset parameters
	int clear_params();

	// Get output
	SV * output(Bytecode * pBytecode);

	// Include directories
	int include_dirs(SV * aIncludeDirs);

	// Load bytecode
	Bytecode * load_bytecode(char * szFileName);

	// Parse template
	Bytecode * parse_template(char * szFileName);

	// Dump parameters
	SV * dump_params();

private:
	// Execution limit
	INT_32                     iStepsLimit;
	// Standard library factory
	CTPP::SyscallFactory     * pSyscallFactory;
	// CDT Object
	CTPP::CDT                * pCDT;
	// Virtual machine
	CTPP::VM                 * pVM;
	// List of include directories
	std::vector<std::string>   vIncludeDirs;

	// Parse given parameters
	int param(SV * pParams, CTPP::CDT * pCDT);
};

#define C_BYTECODE_SOURCE 1
#define C_TEMPLATE_SOURCE 2

//
// Bytecode object
//
class Bytecode
{
public:
	// Save bytecode
	int save(char * szFileName);

	// Destructor
	~Bytecode() throw();

private:
	friend class CTPP2;
	// Default constructor
	Bytecode();
	// Copy constructor
	Bytecode(const Bytecode & oRhs);
	// Operator =
	Bytecode & operator=(const Bytecode & oRhs);

	// Create bytecode object
	Bytecode(char * szFileName, int iFlag);
	// Memory core
	CTPP::VMExecutable   * pCore;
	// Memory core size
	UINT_32                iCoreSize;
	// Ready-to-run program
	CTPP::VMMemoryCore   * pVMMemoryCore;
};

// CTPP2 Implementation //////////////////////////////////////////

CTPP2::CTPP2()
{
	iStepsLimit = 10240;
	using namespace CTPP;
//	fprintf(stderr, "CTPP2::CTPP2\n");
	try
	{
		pCDT = new CTPP::CDT(CTPP::CDT::HASH_VAL);
		pSyscallFactory = new SyscallFactory(1024);
		STDLibInitializer::InitLibrary(*pSyscallFactory);
		pVM = new VM(*pSyscallFactory, 10240, 10240, iStepsLimit);
	}
	catch(...)
	{
		croak("ERROR: Exception in CTPP2::CTPP2(), please contact reki@reki.ru\n");
	}
}

CTPP2::~CTPP2() throw()
{
	using namespace CTPP;
//	fprintf(stderr, "CTPP2::~CTPP2\n");
	try
	{
		// Destroy standard library
		STDLibInitializer::DestroyLibrary(*pSyscallFactory);
		delete pVM;
		delete pCDT;
		delete pSyscallFactory;
	}
	catch(...)
	{
		croak("ERROR: Exception in CTPP2::~CTPP2(), please contact reki@reki.ru\n");
	}
}

//
// Reset parameters
//
int CTPP2::reset()
{
	try
	{
		pCDT -> operator=(CTPP::CDT(CTPP::CDT::HASH_VAL));
	}
	catch(...) { return -1; }
return 0;
}

//
// Reset parameters
//
int CTPP2::clear_params() { return reset(); }

//
// Emit paramaters
//
int CTPP2::param(SV * pParams)
{
	using namespace CTPP;
	try
	{
		return param(pParams, pCDT);
	}
	catch(CTPPLogicError        & e) { croak("ERROR: %s\n", e.what());                                              }
	catch(CTPPUnixException     & e) { croak("ERROR: I/O in %s: %s\n", e.what(), strerror(e.ErrNo()));              }
	catch(CDTTypeCastException  & e) { croak("ERROR: Type Cast %s\n", e.what());                              }
	catch(...) { croak("ERROR: Bad thing happened, please contact reki@reki.ru"); }

return -1;
}

//
// Emit paramaters recursive
//
int CTPP2::param(SV * pParams, CTPP::CDT * pCDT)
{
	long eSVType = SvTYPE(pParams);
//fprintf(stderr, "eSVType = %d\n", I32(eSVType));
	switch (eSVType)
	{
		// 0
		case SVt_NULL:
			;; // Nothing to do?
			break;
		// 1
		case SVt_IV:
			pCDT -> operator=( INT_64( ((xpviv *)(pParams -> sv_any)) -> xiv_iv ) );
			break;
		// 2
		case SVt_NV:
			pCDT -> operator=( W_FLOAT( ((xpvnv *)(pParams -> sv_any)) -> xnv_nv ) );
			break;
		// 3
		case SVt_RV:
			return param(SvRV(pParams), pCDT);
			break;
		// 4
		case SVt_PV:
			{
				STRLEN iLen;
				char * szValue = SvPV(pParams, iLen);
				pCDT -> operator=(std::string(szValue, iLen));
			}
			break;
		// 5
		case SVt_PVIV:
			pCDT -> operator=( INT_64( ((xpviv *)(pParams -> sv_any)) -> xiv_iv) );
			break;
		// 6
		case SVt_PVNV:
			pCDT -> operator=( W_FLOAT( ((xpvnv *)(pParams -> sv_any)) -> xnv_nv ) );
			break;
		// 7
		case SVt_PVMG:
			{
				STRLEN iLen;
				char * szValue = SvPV(pParams, iLen);
				pCDT -> operator=(std::string(szValue, iLen));
			}
			break;
		// 8
		case SVt_PVBM:
			pCDT -> operator=(std::string("*PVBM*", 6)); // Stub!
			break;
		// 9
		case SVt_PVLV:
			pCDT -> operator=(std::string("*PVLV*", 6)); // Stub!
			break;
		// 10
		case SVt_PVAV:
			{
				AV * pArray = (AV *)(pParams);
				I32 iArraySize = av_len(pArray);
				if (pCDT -> GetType() != CTPP::CDT::ARRAY_VAL) { pCDT -> operator=(CTPP::CDT(CTPP::CDT::ARRAY_VAL)); }
				for(I32 iI = 0; iI <= iArraySize; ++iI)
				{
					SV ** pArrElement = av_fetch(pArray, iI, FALSE);
					CTPP::CDT oTMP;
					// Recursive descend
					param(*pArrElement, &oTMP);
					pCDT -> operator[](iI) = oTMP;
				}
			}
			break;
		// 11
		case SVt_PVHV:
			{
				HV * pHash = (HV*)(pParams);
				HE * pHashEntry = NULL;

				if (pCDT -> GetType() != CTPP::CDT::HASH_VAL) { pCDT -> operator=(CTPP::CDT(CTPP::CDT::HASH_VAL)); }
				while ((pHashEntry = hv_iternext(pHash)) != NULL)
				{
					I32 iKeyLen = 0;
					char * szKey  = hv_iterkey(pHashEntry, &iKeyLen);
					SV   * pValue = hv_iterval(pHash, pHashEntry);
					// Recursive descend
					CTPP::CDT oTMP;
					param(pValue, &oTMP);
					pCDT -> operator[](std::string(szKey, iKeyLen)) = oTMP;
				}
			}
			break;
		// 12
		case SVt_PVCV:
			pCDT -> operator=(std::string("*PVCV*", 6)); // Stub!
			break;
		// 13
		case SVt_PVGV:
			pCDT -> operator=(std::string("*PVGV*", 6)); // Stub!
			break;
		// 14
		case SVt_PVFM:
			pCDT -> operator=(std::string("*PVFM*", 6)); // Stub!
			break;
		// 15
		case SVt_PVIO:
			pCDT -> operator=(std::string("*PVIO*", 6)); // Stub!
			break;
		default:
			;;
	}

return 0;
}

//
// Output
//
SV * CTPP2::output(Bytecode * pBytecode)
{
	using namespace CTPP;
	try
	{
		std::string sResult;
		StringOutputCollector oOutputCollector(sResult);

		UINT_32 iIP = 0;
		pVM -> Init(oOutputCollector, *(pBytecode -> pVMMemoryCore));
		pVM -> Run(*(pBytecode -> pVMMemoryCore), iIP, *pCDT);

		return newSVpv(sResult.data(), sResult.length());
	}
	catch(CTPPLogicError        & e) { croak("ERROR: %s\n", e.what());                                              }
	catch(CTPPUnixException     & e) { croak("ERROR: I/O in %s: %s\n", e.what(), strerror(e.ErrNo()));              }
	catch(IllegalOpcode         & e) { croak("ERROR: Illegal opcode 0x%08X at 0x%08X\n", e.GetOpcode(), e.GetIP()); }
	catch(InvalidSyscall        & e) { croak("ERROR: Invalid syscall `%s` at 0x%08X\n", e.what(), e.GetIP());       }
	catch(CodeSegmentOverrun    & e) { croak("ERROR: %s at 0x%08X\n", e.what(),  e.GetIP());                        }
	catch(StackOverflow         & e) { croak("ERROR: Stack overflow at 0x%08X\n", e.GetIP());                       }
	catch(StackUnderflow        & e) { croak("ERROR: Stack underflow at 0x%08X\n", e.GetIP());                      }
	catch(ExecutionLimitReached & e) { croak("ERROR: Execution limit of %d step(s) reached at 0x%08X\n", iStepsLimit, e.GetIP()); }
	catch(CDTTypeCastException  & e) { croak("ERROR: Type Cast %s\n", e.what());  }
	catch(std::exception        & e) { croak("ERROR: STL error: %s\n", e.what()); }
	catch(...) { croak("ERROR: Bad thing happened, please contact reki@reki.ru"); }

return newSVpv("", 0);
}

//
// Include directories
//
int CTPP2::include_dirs(SV * aIncludeDirs)
{
	if (SvTYPE(aIncludeDirs) == SVt_RV) { aIncludeDirs = SvRV(aIncludeDirs); }

	if (SvTYPE(aIncludeDirs) != SVt_PVAV) { croak("Only ARRAY of strings accepted"); return -1; }

	AV * pArray = (AV *)(aIncludeDirs);
	I32 iArraySize = av_len(pArray);

	std::vector<std::string> vTMP;

	for(I32 iI = 0; iI <= iArraySize; ++iI)
	{
		SV ** pArrElement = av_fetch(pArray, iI, FALSE);
		SV *  pElement = *pArrElement;

		if (SvTYPE(pElement) != SVt_PV) { croak("Need STRING at array index %d ", iI); return -1; }

		STRLEN iLen;
		char * szValue = SvPV(pElement, iLen);
		vTMP.push_back(std::string(szValue, iLen));
	}
	vIncludeDirs.swap(vTMP);

return 0;
}

//
// Load bytecode
//
Bytecode * CTPP2::load_bytecode(char * szFileName)
{
	using namespace CTPP;
	try
	{
		return new Bytecode(szFileName, C_BYTECODE_SOURCE);
	}
	catch(CTPPLogicError        & e)
	{
		croak("ERROR: %s\n", e.what());
		return NULL;
	}
	catch(CTPPUnixException     & e)
	{
		croak("ERROR: I/O in %s: %s\n", e.what(), strerror(e.ErrNo()));
		return NULL;
	}
return NULL;
}

//
// Parse template
//
Bytecode * CTPP2::parse_template(char * szFileName)
{
	using namespace CTPP;
	try
	{
		return new Bytecode(szFileName, C_TEMPLATE_SOURCE);
	}
	catch(CTPPLogicError        & e)
	{
		croak("ERROR: %s\n", e.what());
		return NULL;
	}
	catch(CTPPUnixException     & e)
	{
		croak("ERROR: I/O in %s: %s\n", e.what(), strerror(e.ErrNo()));
		return NULL;
	}
	catch(CTPPParserSyntaxError & e)
	{
		croak("ERROR: At line %d, pos. %d: %s\n", e.GetLine(), e.GetLinePos(), e.what());
		return NULL;
	}
	catch (CTPPParserOperatorsMismatch &e)
	{
		croak("ERROR: At line %d, pos. %d: expected %s, but found </%s>\n", e.GetLine(), e.GetLinePos(), e.Expected(), e.Found());
		return NULL;
	}
	catch(...)
	{
		croak("ERROR: Bad thing happened.\n");
		return NULL;
	}
return NULL;
}

//
// Dump parameters
//
SV * CTPP2::dump_params()
{
	try
	{
		std::string sTMP = pCDT -> RecursiveDump();
		return newSVpv(sTMP.data(), sTMP.length());
	}
	catch(...)
	{
		croak("ERROR: Bad thing happened.\n");
	}
return newSVpv("", 0);
}

// Bytecode Implementation /////////////////////////////////////

//
// Constructor
//
Bytecode::Bytecode(char * szFileName, int iFlag): pCore(NULL), pVMMemoryCore(NULL)
{
	using namespace CTPP;
//fprintf(stderr, "Bytecode::Bytecode (%p)\n", this);
	if (iFlag == C_BYTECODE_SOURCE)
	{
		struct stat oStat;

		if (stat(szFileName, &oStat) == 1)
		{
			throw CTPPLogicError("No such file");
		}
		else
		{
			// Get file size
			struct stat oStat;
			if (stat(szFileName, &oStat) == -1) { throw CTPPUnixException("stat", errno); }

			iCoreSize = oStat.st_size;
			if (iCoreSize == 0) { throw CTPPLogicError("Cannot get size of file"); }

			// Load file
			FILE * F = fopen(szFileName, "r");
			if (F == NULL) { throw CTPPUnixException("fopen", errno); }

			// Allocate memory
			pCore = (VMExecutable *)malloc(iCoreSize);
			// Read from file
			(void)fread(pCore, iCoreSize, 1, F);
			// All Done
			fclose(F);

			if (pCore -> magic[0] == 'C' &&
			    pCore -> magic[1] == 'T' &&
			    pCore -> magic[2] == 'P' &&
			    pCore -> magic[3] == 'P')
			{
				pVMMemoryCore = new VMMemoryCore(pCore);
			}
			else
			{
				free(pCore);
				throw CTPPLogicError("Not an CTPP bytecode file.");
			}
		}
//fprintf(stderr, "pCore = %p, pVMMemoryCore = %p\n", pCore, pVMMemoryCore);
	}
	else
	{
		// Load template
		CTPP2FileSourceLoader oSourceLoader;
		oSourceLoader.LoadTemplate(szFileName);

		// Compiler runtime
		VMOpcodeCollector  oVMOpcodeCollector;
		StaticText         oSyscalls;
		StaticData         oStaticData;
		StaticText         oStaticText;
		CTPP2Compiler oCompiler(oVMOpcodeCollector, oSyscalls, oStaticData, oStaticText);

		// Create template parser
		CTPP2Parser oCTPP2Parser(&oSourceLoader, &oCompiler);

		// Compile template
		oCTPP2Parser.Compile();

		// Get program core
		UINT_32 iCodeSize = 0;
		const VMInstruction * oVMInstruction = oVMOpcodeCollector.GetCode(iCodeSize);

		// Dump program
		VMDumper oDumper(iCodeSize, oVMInstruction, oSyscalls, oStaticData, oStaticText);
		const VMExecutable * aProgramCore = oDumper.GetExecutable(iCoreSize);

		// Allocate memory
		pCore = (VMExecutable *)malloc(iCoreSize);
		memcpy(pCore, aProgramCore, iCoreSize);
		pVMMemoryCore = new VMMemoryCore(pCore);
//fprintf(stderr, "pCore = %p, pVMMemoryCore = %p\n", pCore, pVMMemoryCore);
	}
}

//
// Save bytecode
//
int Bytecode::save(char * szFileName)
{
	// Open file only if compilation is done
	FILE * FW = fopen(szFileName, "w");
	if (FW == NULL) { croak("ERROR: Cannot open destination file `%s` for writing\n", szFileName); return -1; }

	// Write to the disc
	(void)fwrite(pCore, iCoreSize, 1, FW);
	// All done
	fclose(FW);
return 0;
}

//
// Destructor
//
Bytecode::~Bytecode() throw()
{
//fprintf(stderr, "Bytecode::~Bytecode(%p) %p - %p\n", this, pCore,  pVMMemoryCore);
	delete pVMMemoryCore;
	free(pCore);
}


MODULE = HTML::CTPP2		PACKAGE = HTML::CTPP2

CTPP2 *
CTPP2::new()

void
CTPP2::DESTROY()

int
CTPP2::param(SV * pParams)

int
CTPP2::reset()

int
CTPP2::clear_params()

SV *
CTPP2::output(Bytecode * pBytecode)

int
CTPP2::include_dirs(SV * aIncludeDirs)

SV *
CTPP2::load_bytecode(char * szFileName)
    CODE:
        Bytecode * pBytecode = THIS -> load_bytecode(szFileName);
        ST(0) = sv_newmortal();
        sv_setref_pv( ST(0), "HTML::CTPP2::Bytecode", (void*)pBytecode );
        XSRETURN(1);

SV *
CTPP2::parse_template(char * szFileName)
    CODE:
        Bytecode * pBytecode = THIS -> parse_template(szFileName);
        ST(0) = sv_newmortal();
        sv_setref_pv( ST(0), "HTML::CTPP2::Bytecode", (void*)pBytecode );
        XSRETURN(1);

SV *
CTPP2::dump_params()

MODULE = HTML::CTPP2		PACKAGE = HTML::CTPP2::Bytecode

int
Bytecode::save(char * szFileName)

void
Bytecode::DESTROY()


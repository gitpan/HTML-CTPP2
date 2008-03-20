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

#include <dlfcn.h>

// FWD
class Bytecode;

//
// CTPP2 main object
//
class CTPP2
{
public:
	// Constructor
	CTPP2(const UINT_32 & iArgStackSize, const UINT_32 & iCodeStackSize, const UINT_32 & iStepsLimit, const UINT_32 & iMaxFunctions);

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

	// Load user defined function
	int load_udf(char * szLibraryName, char * szInstanceName);

private:
	typedef CTPP::SyscallHandler * ((*InitPtr)());

	struct HandlerRefsSort:
	  public std::binary_function<std::string, std::string, bool>
	{
		/**
		  @brief comparison operator
		  @param x - first argument
		  @param y - first argument
		  @return true if x > y
		*/
		inline bool operator() (const std::string &x, const std::string &y) const
		{
			return (strcasecmp(x.c_str(), y.c_str()) > 0);
		}
	};

	// Loadable user-defined function
	struct LoadableUDF
	{
		// Function file name
		std::string             filename;
		// Function name
		std::string             udf_name;
		// Function instance
		CTPP::SyscallHandler  * udf;
	};

	// List of include directories
	std::map<std::string, LoadableUDF, HandlerRefsSort> mExtraFn;
	// Execution limit
	INT_32                               iStepsLimit;
	// Standard library factory
	CTPP::SyscallFactory               * pSyscallFactory;
	// CDT Object
	CTPP::CDT                          * pCDT;
	// Virtual machine
	CTPP::VM                           * pVM;
	// List of include directories
	std::vector<std::string>             vIncludeDirs;

	// Parse given parameters
	int param(SV * pParams, CTPP::CDT * pCDT, CTPP::CDT * pUplinkCDT, const std::string & sKey, int iPrevIsHash, int & iProcessed);

};

#define C_BYTECODE_SOURCE 1
#define C_TEMPLATE_SOURCE 2

#define C_PREV_LEVEL_IS_HASH     1
#define C_PREV_LEVEL_IS_UNKNOWN  2

#define C_INIT_SYM_PREFIX "_init"

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
	Bytecode(char * szFileName, int iFlag, const std::vector<std::string> & vIncludeDirs);
	// Memory core
	CTPP::VMExecutable   * pCore;
	// Memory core size
	UINT_32                iCoreSize;
	// Ready-to-run program
	CTPP::VMMemoryCore   * pVMMemoryCore;
};

// CTPP2 Implementation //////////////////////////////////////////

//
// Constructor
//
CTPP2::CTPP2(const UINT_32 & iArgStackSize, const UINT_32 & iCodeStackSize, const UINT_32 & iStepsLimit, const UINT_32 & iMaxFunctions)
{
	using namespace CTPP;
	try
	{
		pCDT = new CTPP::CDT(CTPP::CDT::HASH_VAL);
		pSyscallFactory = new SyscallFactory(iMaxFunctions);
		STDLibInitializer::InitLibrary(*pSyscallFactory);
		pVM = new VM(*pSyscallFactory, iArgStackSize, iCodeStackSize, iStepsLimit);
	}
	catch(...)
	{
		croak("ERROR: Exception in CTPP2::CTPP2(), please contact reki@reki.ru");
	}
}

//
// Destructor
//
CTPP2::~CTPP2() throw()
{
	using namespace CTPP;
	try
	{
		// Destroy standard library
		STDLibInitializer::DestroyLibrary(*pSyscallFactory);

		std::map<std::string, LoadableUDF, HandlerRefsSort>::iterator itmExtraFn = mExtraFn.begin();
		while (itmExtraFn != mExtraFn.end())
		{
			pSyscallFactory -> RemoveHandler(itmExtraFn -> second.udf -> GetName());
			delete itmExtraFn -> second.udf;
			++itmExtraFn;
		}

		delete pVM;
		delete pCDT;
		delete pSyscallFactory;
	}
	catch(...)
	{
		croak("ERROR: Exception in CTPP2::~CTPP2(), please contact reki@reki.ru");
	}
}

//
// Load user defined function
//
int CTPP2::load_udf(char * szLibraryName, char * szInstanceName)
{
	std::map<std::string, LoadableUDF, HandlerRefsSort>::iterator itmExtraFn = mExtraFn.find(szInstanceName);
	// Function already present?
	if (itmExtraFn != mExtraFn.end() || pSyscallFactory -> GetHandlerByName(szInstanceName) != NULL)
	{
 		croak("ERROR in load_udf(): Function `%s` already present", szInstanceName);
		return -1;
	}

	// Okay, try to load function

	void * vLibrary = dlopen(szLibraryName, RTLD_NOW | RTLD_GLOBAL);
	// Error?
	if (vLibrary == NULL)
	{
		croak("ERROR in load_udf(): Cannot load library `%s`: `%s`", szLibraryName, dlerror());
		return -1;
	}

	// Init String
	INT_32 iInstanceNameLen = strlen(szInstanceName);
	CHAR_P szInitString = (CHAR_P)malloc(sizeof(CHAR_8) * (iInstanceNameLen + sizeof(C_INIT_SYM_PREFIX) + 1));
	memcpy(szInitString, szInstanceName, iInstanceNameLen);
	memcpy(szInitString + iInstanceNameLen, C_INIT_SYM_PREFIX, sizeof(C_INIT_SYM_PREFIX));
	szInitString[iInstanceNameLen + sizeof(C_INIT_SYM_PREFIX)]= '\0';

	// This is UGLY hack to avoid stupid gcc warnings
	// InitPtr vVInitPtr = (InitPtr)dlsym(vLibrary, szInitString); // this code violates C++ Standard
	void * vTMPPtr = dlsym(vLibrary, szInitString);

	free(szInitString);

	if (vTMPPtr == NULL)
	{
		croak("ERROR in load_udf(): in `%s`: cannot find function `%s`", szLibraryName, szInstanceName);
		return -1;
	}

	// This is UGLY hack to avoid stupid gcc warnings
	InitPtr vVInitPtr = NULL;
	// and this code - is correct C++ code
	memcpy(&vVInitPtr, &vTMPPtr, sizeof(void *));

	CTPP::SyscallHandler * pUDF = (CTPP::SyscallHandler *)((*vVInitPtr)());

	LoadableUDF oLoadableUDF;

	oLoadableUDF.filename = szLibraryName;
	oLoadableUDF.udf_name = szInstanceName;
	oLoadableUDF.udf      = pUDF;

	mExtraFn.insert(std::pair<std::string, LoadableUDF>(szInstanceName, oLoadableUDF));

	pSyscallFactory -> RegisterHandler(pUDF);

return 0;
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
		int iTMP;
		return param(pParams, pCDT, pCDT, "", C_PREV_LEVEL_IS_UNKNOWN, iTMP);
	}
	catch(CTPPLogicError        & e) { croak("ERROR in param(): %s", e.what());                                  }
	catch(CTPPUnixException     & e) { croak("ERROR in param(): I/O in %s: %s", e.what(), strerror(e.ErrNo()));  }
	catch(CDTTypeCastException  & e) { croak("ERROR in param(): Type Cast %s", e.what());                        }
	catch(std::exception        & e) { croak("ERROR in param(): %s", e.what());                                    }
	catch(...)                       { croak("ERROR in param(): Bad thing happened, please contact reki@reki.ru"); }

return -1;
}

//
// Emit paramaters recursive
//
int CTPP2::param(SV * pParams, CTPP::CDT * pCDT, CTPP::CDT * pUplinkCDT, const std::string & sKey, int iPrevIsHash, int & iProcessed)
{
	iProcessed = 0;
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
			return param(SvRV(pParams), pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
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
		// 6
		case SVt_PVNV:
		// 7
		case SVt_PVMG:
				if      (SvIOK(pParams)) { pCDT -> operator=( INT_64( ((xpviv *)(pParams -> sv_any)) -> xiv_iv ) ); }
				else if (SvNOK(pParams)) { pCDT -> operator=( W_FLOAT( ((xpvnv *)(pParams -> sv_any)) -> xnv_nv ) ); }
				else if (SvPOK(pParams))
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
				int iTMPProcessed = 0;
				if (pCDT -> GetType() != CTPP::CDT::ARRAY_VAL) { pCDT -> operator=(CTPP::CDT(CTPP::CDT::ARRAY_VAL)); }
				for(I32 iI = 0; iI <= iArraySize; ++iI)
				{
					SV ** pArrElement = av_fetch(pArray, iI, FALSE);

					CTPP::CDT oTMP;
					// Recursive descend
					param(*pArrElement, &oTMP, &oTMP, sKey, C_PREV_LEVEL_IS_UNKNOWN, iTMPProcessed);
					pCDT -> operator[](iI) = oTMP;
				}
			}
			break;
		// 11
		case SVt_PVHV:
			{
				HV * pHash = (HV*)(pParams);
				HE * pHashEntry = NULL;
				// If prevoius level is array, do nothing
				if (iPrevIsHash == C_PREV_LEVEL_IS_UNKNOWN)
				{
					int iProcessed = 0;
					if (pCDT -> GetType() != CTPP::CDT::HASH_VAL) { pCDT -> operator=(CTPP::CDT(CTPP::CDT::HASH_VAL)); }
					while ((pHashEntry = hv_iternext(pHash)) != NULL)
					{
						I32 iKeyLen = 0;
						char * szKey  = hv_iterkey(pHashEntry, &iKeyLen);
						SV   * pValue = hv_iterval(pHash, pHashEntry);
						std::string sTMPKey(szKey, iKeyLen);

						CTPP::CDT oTMP;
						param(pValue, &oTMP, pUplinkCDT, sTMPKey, C_PREV_LEVEL_IS_HASH, iProcessed);
						if (iProcessed == 0)
						{
							pCDT -> operator[](sTMPKey) = oTMP;
						}
						else
						{
							pCDT -> operator[](sTMPKey) = 1;
						}
					}
				}
				else
				{
					if (pCDT -> GetType() != CTPP::CDT::HASH_VAL) { pCDT -> operator=(CTPP::CDT(CTPP::CDT::HASH_VAL)); }
					while ((pHashEntry = hv_iternext(pHash)) != NULL)
					{
						I32 iKeyLen = 0;
						char * szKey  = hv_iterkey(pHashEntry, &iKeyLen);
						SV   * pValue = hv_iterval(pHash, pHashEntry);

						std::string sTMPKey(sKey);
						sTMPKey.append(".", 1);
						sTMPKey.append(szKey, iKeyLen);

						CTPP::CDT oTMP;
						param(pValue, &oTMP, pUplinkCDT, sTMPKey, C_PREV_LEVEL_IS_HASH, iProcessed);
						if (iProcessed == 0)
						{
							pUplinkCDT -> operator[](sTMPKey) = oTMP;
							iProcessed = 1;
						}
						else
						{
							pUplinkCDT -> operator[](sTMPKey) = 1;
						}
					}
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
	catch(CTPPLogicError        & e) { croak("ERROR in output(): %s", e.what());                                              }
	catch(CTPPUnixException     & e) { croak("ERROR in output(): I/O in %s: %s", e.what(), strerror(e.ErrNo()));              }
	catch(IllegalOpcode         & e) { croak("ERROR in output(): Illegal opcode 0x%08X at 0x%08X", e.GetOpcode(), e.GetIP()); }
	catch(InvalidSyscall        & e) { croak("ERROR in output(): Invalid syscall `%s` at 0x%08X", e.what(), e.GetIP());       }
	catch(CodeSegmentOverrun    & e) { croak("ERROR in output(): %s at 0x%08X", e.what(),  e.GetIP());                        }
	catch(StackOverflow         & e) { croak("ERROR in output(): Stack overflow at 0x%08X", e.GetIP());                       }
	catch(StackUnderflow        & e) { croak("ERROR in output(): Stack underflow at 0x%08X", e.GetIP());                      }
	catch(ExecutionLimitReached & e) { croak("ERROR in output(): Execution limit of %d step(s) reached at 0x%08X", iStepsLimit, e.GetIP()); }
	catch(CDTTypeCastException  & e) { croak("ERROR in output(): Type Cast %s", e.what());  }
	catch(std::exception        & e) { croak("ERROR in output(): STL error: %s", e.what()); }
	catch(...) { croak("ERROR: Bad thing happened, please contact reki@reki.ru"); }

return newSVpv("", 0);
}

//
// Include directories
//
int CTPP2::include_dirs(SV * aIncludeDirs)
{
	if (SvTYPE(aIncludeDirs) == SVt_RV) { aIncludeDirs = SvRV(aIncludeDirs); }

	if (SvTYPE(aIncludeDirs) != SVt_PVAV) { croak("ERROR in include_dirs(): Only ARRAY of strings accepted"); return -1; }

	AV * pArray = (AV *)(aIncludeDirs);
	I32 iArraySize = av_len(pArray);

	std::vector<std::string> vTMP;

	for(I32 iI = 0; iI <= iArraySize; ++iI)
	{
		SV ** pArrElement = av_fetch(pArray, iI, FALSE);
		SV *  pElement = *pArrElement;

		if (SvTYPE(pElement) != SVt_PV) { croak("ERROR in include_dirs(): Need STRING at array index %d", iI); return -1; }

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
		return new Bytecode(szFileName, C_BYTECODE_SOURCE, vIncludeDirs);
	}
	catch(CTPPLogicError        & e)
	{
		croak("ERROR in load_bytecode(): %s", e.what());
		return NULL;
	}
	catch(CTPPUnixException     & e)
	{
		croak("ERROR in load_bytecode(): I/O in %s: %s", e.what(), strerror(e.ErrNo()));
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
		return new Bytecode(szFileName, C_TEMPLATE_SOURCE, vIncludeDirs);
	}
	catch(CTPPLogicError        & e)
	{
		croak("ERROR in parse_template(): %s", e.what());
		return NULL;
	}
	catch(CTPPUnixException     & e)
	{
		croak("ERROR in parse_template(): I/O in %s: %s", e.what(), strerror(e.ErrNo()));
		return NULL;
	}
	catch(CTPPParserSyntaxError & e)
	{
		croak("ERROR in parse_template(): At line %d, pos. %d: %s", e.GetLine(), e.GetLinePos(), e.what());
		return NULL;
	}
	catch (CTPPParserOperatorsMismatch &e)
	{
		croak("ERROR in parse_template(): At line %d, pos. %d: expected %s, but found </%s>", e.GetLine(), e.GetLinePos(), e.Expected(), e.Found());
		return NULL;
	}
	catch(...)
	{
		croak("ERROR in parse_template(): Bad thing happened.");
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
		croak("ERROR in dump_params(): Bad thing happened.");
	}
return newSVpv("", 0);
}

// Bytecode Implementation /////////////////////////////////////

//
// Constructor
//
Bytecode::Bytecode(char * szFileName, int iFlag, const std::vector<std::string> & vIncludeDirs): pCore(NULL), pVMMemoryCore(NULL)
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
		oSourceLoader.SetIncludeDirs(vIncludeDirs);
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
	if (FW == NULL) { croak("ERROR: Cannot open destination file `%s` for writing", szFileName); return -1; }

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
CTPP2::new(...)
    CODE:
	UINT_32 iArgStackSize  = 10240;
	UINT_32 iCodeStackSize = 10240;
	UINT_32 iStepsLimit    = 1048576;
	UINT_32 iMaxFunctions  = 1024;

	if (items % 2 != 1)
	{
		croak("ERROR: new HTML::CTPP2() called with odd number of option parameters - should be of the form option => value");
	}

	for (INT_32 iI = 1; iI < items; iI+=2)
	{
		STRLEN iKeyLen = 0;
		STRLEN iValLen = 0;

		char * szKey   = NULL;
		char * szValue = NULL;

		long eSVType = SvTYPE(ST(iI));

		switch (eSVType)
		{
			case SVt_IV:
			case SVt_NV:
			case SVt_RV:
			case SVt_PV:
			case SVt_PVIV:
			case SVt_PVNV:
			case SVt_PVMG:
				szKey = SvPV(ST(iI), iKeyLen);
				break;

			default:
				croak("ERROR: Parameter name expected");
		}

		eSVType = SvTYPE(ST(iI + 1));

		switch (eSVType)
		{
			case SVt_IV:
			case SVt_NV:
			case SVt_RV:
			case SVt_PV:
			case SVt_PVIV:
			case SVt_PVNV:
			case SVt_PVMG:
				szValue = SvPV(ST(iI + 1), iValLen);
				break;
			default:
				croak("ERROR: Parameter name expected");
		}
		if (strncasecmp("arg_stack_size", szKey, iKeyLen) == 0)
		{
			sscanf(szValue, "%u", &iArgStackSize);
			if (iArgStackSize == 0) { croak("ERROR: parameter 'arg_stack_size' should be > 0"); }
		}
		else if (strncasecmp("code_stack_size", szKey, iKeyLen) == 0)
		{
			sscanf(szValue, "%u", &iCodeStackSize);
			if (iCodeStackSize == 0) { croak("ERROR: parameter 'code_stack_size' should be > 0"); }
		}
		else if (strncasecmp("steps_limit", szKey, iKeyLen) == 0)
		{
			sscanf(szValue, "%u", &iStepsLimit);
			if (iStepsLimit == 0) { croak("ERROR: parameter 'steps_limit' should be > 0"); }
		}
		else if (strncasecmp("max_functions", szKey, iKeyLen) == 0)
		{
			sscanf(szValue, "%u", &iMaxFunctions);
			if (iMaxFunctions == 0) { croak("ERROR: parameter 'max_functions' should be > 0"); }
		}
		else
		{
			croak("ERROR: Unknown parameter name: `%s`", szKey);
		}
	}
	RETVAL = new CTPP2(iArgStackSize, iCodeStackSize, iStepsLimit, iMaxFunctions);
    OUTPUT:
	RETVAL

void
CTPP2::DESTROY()

int
CTPP2::load_udf(char * szLibraryName, char * szInstanceName)

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

/*-
 * Copyright (c) 2006 - 2009 CTPP Team
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
#include "perliol.h"

#include "ppport.h"
#ifdef __cplusplus
}
#endif

#include <dlfcn.h>

using CTPP::CTPPError;

// FWD
class Bytecode;

//
// CTPP2 main object
//
class CTPP2
{
public:
	// Constructor
	CTPP2(const UINT_32      & iArgStackSize,
	      const UINT_32      & iCodeStackSize,
	      const UINT_32      & iStepsLimit,
	      const UINT_32      & iMaxFunctions,
	      const std::string  & sSourceCharset,
	      const std::string  & sDestCharset);

	// Destructor
	~CTPP2() throw();

	// Emit parameters
	int param(SV * pParams);

	// Reset parameters
	int reset();

	// Reset parameters
	int clear_params();

	// Emit JSON parameters
	int json_param(SV * pParams);

	// Get output
	SV * output(Bytecode     * pBytecode,
	            std::string    sSourceCharset,
	            std::string    sDestCharset);

	// Include directories
	int include_dirs(SV * aIncludeDirs);

	// Load bytecode
	Bytecode * load_bytecode(char * szFileName);

	// Parse template
	Bytecode * parse_template(char * szFileName);

	// Parse block of text
	Bytecode * parse_text(SV * sText);

	// Dump parameters
	SV * dump_params();

	// Load user defined function
	int load_udf(char * szLibraryName, char * szInstanceName);

	// Get hash with last error description
	SV * get_last_error();

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
	// Error Description
	CTPPError                            oCTPPError;
	// Source charset
	std::string                          sSrcEnc;
	// Destination charset
	std::string                          sDstEnc;
	// Use charset recoder or not
	bool                                 bUseRecoder;
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

	// Create bytecode object from text block
	Bytecode(SV * sText, const std::vector<std::string> & vIncludeDirs);

	// Create bytecode object
	Bytecode(char * szFileName, int iFlag, const std::vector<std::string> & vIncludeDirs);

	// Memory core
	CTPP::VMExecutable   * pCore;
	// Memory core size
	UINT_32                iCoreSize;
	// Ready-to-run program
	CTPP::VMMemoryCore   * pVMMemoryCore;
};


//
// Source loader
//
class CTPP2TextSourceLoader:
  public CTPP::CTPP2SourceLoader
{
public:
	/**
	  @brief Constructor
	*/
	CTPP2TextSourceLoader(const std::string & sTemplate);

	/**
	  @brief A destructor
	*/
	~CTPP2TextSourceLoader() throw();

	/**
	  @brief Set include directories
	*/
	void SetIncludeDirs(const std::vector<std::string> & vIIncludeDirs);

private:
	const std::string     sTemplate;

	CTPP::CTPP2FileSourceLoader oFileLoader;

	/**
	  @brief Load template with specified name
	  @param szTemplateName - template name
	  @return 0 if success, -1 if any error occured
	*/
	INT_32 LoadTemplate(CCHAR_P szTemplateName);

	/**
	  @brief Get template
	  @param iTemplateSize - template size [out]
	  @return pointer to start of template buffer if success, NULL - if any error occured
	*/
	CCHAR_P GetTemplate(UINT_32 & iTemplateSize);

	/**
	  @brief Clone loader object
	  @return clone to self
	*/
	CTPP2SourceLoader * Clone();
};

// CTPP2 Implementation //////////////////////////////////////////

//
// Constructor
//
CTPP2::CTPP2(const UINT_32      & iArgStackSize,
             const UINT_32      & iCodeStackSize,
             const UINT_32      & iStepsLimit,
             const UINT_32      & iMaxFunctions,
             const std::string  & sSourceCharset,
             const std::string  & sDestCharset): pCDT(NULL), pSyscallFactory(NULL), pVM(NULL)
{
	using namespace CTPP;
	try
	{
		pCDT            = new CTPP::CDT(CTPP::CDT::HASH_VAL);
		pSyscallFactory = new SyscallFactory(iMaxFunctions);
		STDLibInitializer::InitLibrary(*pSyscallFactory);

		pVM             = new VM(*pSyscallFactory, iArgStackSize, iCodeStackSize, iStepsLimit);

		if (sSourceCharset.size() && sDestCharset.size())
		{
			sSrcEnc = sSourceCharset;
			sDstEnc = sDestCharset;
			bUseRecoder = true;
		}
		else { bUseRecoder = false; }
	}
	catch(...)
	{
		// Throw waste
		if (pCDT            != NULL) { delete pCDT;            }
		if (pSyscallFactory != NULL)
		{
			STDLibInitializer::DestroyLibrary(*pSyscallFactory);
			delete pSyscallFactory;
		}

		// Unrecoverable error
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
		// Unrecoverable error
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
		oCTPPError = CTPPError("", std::string("Function `") + szInstanceName + "` already present", CTPP_DATA_ERROR | CTPP_LOGIC_ERROR, 0, 0, 0);
 		warn("ERROR in load_udf(): Function `%s` already present", szInstanceName);
		return -1;
	}

	// Okay, try to load function
	void * vLibrary = dlopen(szLibraryName, RTLD_NOW | RTLD_GLOBAL);

	// Error?
	if (vLibrary == NULL)
	{
		oCTPPError = CTPPError("", std::string("Cannot load library `") + szLibraryName + "`: `" + dlerror() + "`", CTPP_DATA_ERROR | CTPP_LOGIC_ERROR, 0, 0, 0);
		warn("ERROR in load_udf(): Cannot load library `%s`: `%s`", szLibraryName, dlerror());
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
		oCTPPError = CTPPError("", std::string("in `") + szLibraryName + "`: cannot find function `" + szInstanceName + "`");
		warn("ERROR in load_udf(): in `%s`: cannot find function `%s`", szLibraryName, szInstanceName);
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
	using namespace CTPP;
	/* Reset data */
	INT_32      iOK = -1;
	try
	{
		pCDT -> operator=(CDT(CDT::HASH_VAL));

		iOK = 0;
	}
	catch (CDTTypeCastException  & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_TYPE_CAST_ERROR,      0, 0, 0); }
	catch (...)                        { oCTPPError = CTPPError("", "Unknown Error", CTPP_DATA_ERROR | STL_UNKNOWN_ERROR, 0, 0, 0); }

	// Error occured
	if (iOK == -1)
	{
		warn("reset(): %s (error code 0x%08X)", oCTPPError.error_descr.c_str(),
		                                        oCTPPError.error_code);
	}

return iOK;
}

//
// Reset parameters
//
int CTPP2::clear_params() { return reset(); }

// Emit JSON parameters
int CTPP2::json_param(SV * pParams)
{
	using namespace CTPP;

	long eSVType = SvTYPE(pParams);

	STRLEN        iJSONLen = 0;
#ifdef SvPV_const
	const char  * szJSON   = NULL;
#else
	char        * szJSON   = NULL;
#endif

	int    iOK = -1;

	switch (eSVType)
	{
		case SVt_IV:
		case SVt_NV:
		case SVt_RV:
		case SVt_PV:
		case SVt_PVIV:
		case SVt_PVNV:
		case SVt_PVMG:
#ifdef SvPV_const // More effcetive way to get values
			szJSON = SvPV_const(pParams, iJSONLen);
#else
			szJSON = SvPV(pParams, iJSONLen);
#endif
			break;

			default:
				oCTPPError = CTPPError("", "String expected", CTPP_DATA_ERROR | CTPP_LOGIC_ERROR,      0, 0, 0);
				warn("ERROR: String expected");
				return -1;
	}

	try
	{
		CTPP2JSONParser oJSONParser(*pCDT);

		if (szJSON != NULL) { oJSONParser.Parse(szJSON, szJSON + iJSONLen); }

		iOK = 0;
	}
	catch (CTPPParserSyntaxError        & e)
	{
		oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | CTPP_SYNTAX_ERROR, e.GetLine(), e.GetLinePos(), 0);
	}
	catch (CTPPParserOperatorsMismatch  & e)
	{
		oCTPPError = CTPPError("", std::string("Expected ") + e.Expected() + ", but found " + e.Found(), CTPP_COMPILER_ERROR | CTPP_SYNTAX_ERROR, e.GetLine(), e.GetLinePos(), 0);
	}
	catch (CTPPUnixException            & e) { oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | CTPP_UNIX_ERROR, 0, 0, 0); }
	catch (CDTRangeException            & e) { oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | CTPP_RANGE_ERROR, 0, 0, 0); }
	catch (CDTAccessException           & e) { oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | CTPP_ACCESS_ERROR, 0, 0, 0); }
	catch (CDTTypeCastException         & e) { oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | CTPP_TYPE_CAST_ERROR, 0, 0, 0); }
	catch (CTPPLogicError               & e) { oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | CTPP_LOGIC_ERROR, 0, 0, 0); }
	catch (CTPPException                & e) { oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | CTPP_UNKNOWN_ERROR, 0, 0, 0); }
	catch (std::exception               & e) { oCTPPError = CTPPError("", e.what(), CTPP_COMPILER_ERROR | STL_UNKNOWN_ERROR, 0, 0, 0); }
	catch (...)                              { oCTPPError = CTPPError("", "Unknown Error", CTPP_COMPILER_ERROR | STL_UNKNOWN_ERROR, 0, 0, 0); }

	// Error occured
	if (iOK == -1)
	{
		if (oCTPPError.line != 0)
		{
			warn("json_param(): %s (error code 0x%08X) at line %d pos %d", oCTPPError.error_descr.c_str(),
			                                                               oCTPPError.error_code,
			                                                               oCTPPError.line,
			                                                               oCTPPError.pos);
		}
		else
		{
			warn("json_param(): %s (error code 0x%08X)", oCTPPError.error_descr.c_str(),
			                                             oCTPPError.error_code);
		}
	}

return iOK;
}

//
// Emit paramaters
//
int CTPP2::param(SV * pParams)
{
	using namespace CTPP;
	INT_32      iOK = -1;
	try
	{
		int iTMP;
		iOK = param(pParams, pCDT, pCDT, "", C_PREV_LEVEL_IS_UNKNOWN, iTMP);
	}
	catch (CDTRangeException      & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_RANGE_ERROR,         0, 0, 0); }
	catch (CDTAccessException     & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_ACCESS_ERROR,        0, 0, 0); }
	catch (CDTTypeCastException   & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_TYPE_CAST_ERROR,     0, 0, 0); }
	catch (CTPPLogicError         & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_LOGIC_ERROR,         0, 0, 0); }
	catch (CTPPException          & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_UNKNOWN_ERROR,       0, 0, 0); }
	catch (std::exception         & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | STL_UNKNOWN_ERROR,        0, 0, 0); }
	catch (...)                        { oCTPPError = CTPPError("", "Unknown Error", CTPP_DATA_ERROR | STL_UNKNOWN_ERROR, 0, 0, 0); }

	// Error occured
	if (iOK == -1)
	{
		warn("param(): %s (error code 0x%08X)", oCTPPError.error_descr.c_str(),
		                                        oCTPPError.error_code);
	}

return iOK;
}

//
// Emit paramaters recursive
//
int CTPP2::param(SV * pParams, CTPP::CDT * pCDT, CTPP::CDT * pUplinkCDT, const std::string & sKey, int iPrevIsHash, int & iProcessed)
{
	iProcessed = 0;
	if (pParams == NULL) { return 0; }
	long eSVType = SvTYPE(pParams);

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
#if ((PERL_API_VERSION == 8) || (PERL_API_VERSION == 6))
			pCDT -> operator=( W_FLOAT( ((xpvnv *)(pParams -> sv_any)) -> xnv_nv ) );
#elif (PERL_API_VERSION == 10)
			pCDT -> operator=( W_FLOAT( ((xpvnv *)(pParams -> sv_any)) -> xnv_u.xnv_nv ) );
#else
    #error "This version of perl not supported yet!"
#endif
			break;
		// 3
		case SVt_RV:
			return param(SvRV(pParams), pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
			break;
		// 4
		case SVt_PV:
			{
				if (SvPOK(pParams))
				{
					STRLEN iLen;
#ifdef SvPV_const // More effcetive way to get values
					const char * szValue = SvPV_const(pParams, iLen);
#else
					char * szValue = SvPV(pParams, iLen);
#endif
					pCDT -> operator=(std::string(szValue, iLen));
				}
				else if (SvROK(pParams))
				{
					return param(SvRV(pParams), pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
				}
			}
			break;
		// 5
		case SVt_PVIV:
		// 6
		case SVt_PVNV:
		// 7
		case SVt_PVMG:
				if      (SvIOK(pParams)) { pCDT -> operator=( INT_64( ((xpviv *)(pParams -> sv_any)) -> xiv_iv ) ); }
				else if (SvNOK(pParams))
				{
#if ((PERL_API_VERSION == 8) || (PERL_API_VERSION == 6))
					pCDT -> operator=( W_FLOAT( ((xpvnv *)(pParams -> sv_any)) -> xnv_nv ) );
#elif (PERL_API_VERSION == 10)
					pCDT -> operator=( W_FLOAT( ((xpvnv *)(pParams -> sv_any)) -> xnv_u.xnv_nv ) );
#else
    #error "This version of perl not supported yet!"
#endif

				}
				else if (SvPOK(pParams))
				{
					STRLEN iLen;
#ifdef SvPV_const // More effcetive way to get values
					const char * szValue = SvPV_const(pParams, iLen);
#else
					char * szValue = SvPV(pParams, iLen);
#endif
					pCDT -> operator=(std::string(szValue, iLen));
				}
				else if (SvROK(pParams))
				{
					return param(SvRV(pParams), pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
				}
				// Undef
				else if (!SvOK(pParams))
				{
					pCDT -> operator=(CTPP::CDT());
				}
				// Stash
				else if (SvSTASH(pParams))
				{
					return param((SV*)SvSTASH(pParams), pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
				}
				// Our stash
				else if (SvPAD_OUR(pParams))
				{
					return param((SV*)SvOURSTASH(pParams), pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
				}
				// Stub for unknown Perl types
				else
				{
					pCDT -> operator=(std::string("SVt_PVMG: "));
					pCDT -> operator+=(UINT_32(SvFLAGS(pParams)));
				}
			break;
		// 8/
#if ((PERL_API_VERSION == 8) || (PERL_API_VERSION == 6))
		case SVt_PVBM:
			pCDT -> operator=(std::string("*PVBM*", 6)); // Stub!
			break;
#endif
		// 9
		case SVt_PVLV:
			pCDT -> operator=(std::string("*PVLV*", 6)); // Stub!
			break;
		// 10
		case SVt_PVAV:
			{
				AV * pArray = (AV *)(pParams);
				if (pArray == NULL) { return 0; }

				I32 iArraySize = av_len(pArray);
				int iTMPProcessed = 0;
				if (pCDT -> GetType() != CTPP::CDT::ARRAY_VAL) { pCDT -> operator=(CTPP::CDT(CTPP::CDT::ARRAY_VAL)); }
				for(I32 iI = 0; iI <= iArraySize; ++iI)
				{
					SV ** pArrElement = av_fetch(pArray, iI, FALSE);

					CTPP::CDT oTMP;
					// Recursive descend
					if (pArrElement != NULL) { param(*pArrElement, &oTMP, &oTMP, sKey, C_PREV_LEVEL_IS_UNKNOWN, iTMPProcessed); }
					pCDT -> operator[](iI) = oTMP;
				}
			}
			break;
		// 11
		case SVt_PVHV:
			{
				HV * pHash = (HV*)(pParams);
				hv_iterinit(pHash);
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
						if (pValue != NULL)
						{
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
			{
				CV * pCV = (CV*)pParams;

				dSP;
				ENTER; SAVETMPS; PUSHMARK(SP);
				PUTBACK;
				call_sv((SV *)pCV, G_SCALAR);
				SPAGAIN;
				pParams = POPs;

				try
				{
					param(pParams, pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
				}
				catch(...)
				{
					PUTBACK;
					FREETMPS; LEAVE;
					throw;
				}

				PUTBACK;
				FREETMPS; LEAVE;
			}
			break;
		// 13
		case SVt_PVGV:
			{
				GV * pFN = gv_fetchmethod_autoload(SvSTASH(pParams), "(\"\"", 0);
				if (pFN == NULL)
				{
					pCDT -> operator=(CTPP::CDT::UNDEF);
				}
				else
				{
					dSP;
					ENTER; SAVETMPS; PUSHMARK(SP);
					XPUSHs(sv_bless(sv_2mortal(newRV_inc(pParams)), SvSTASH(pParams)));
					PUTBACK;
					call_sv((SV *)GvCV (pFN), G_SCALAR);
					SPAGAIN;
					if (SvROK(TOPs) && SvRV(TOPs) == pParams)
					{
						croak("%s::(\"\" stringification method returned same object as was passed instead of a new one", HvNAME(SvSTASH(pParams)));
						return -1;
					}

					pParams = POPs;
					try
					{
						param(pParams, pCDT, pUplinkCDT, sKey, iPrevIsHash, iProcessed);
					}
					catch(...)
					{
						PUTBACK;
						FREETMPS; LEAVE;
						throw;
					}

					PUTBACK;
					FREETMPS; LEAVE;
				}
			}
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
SV * CTPP2::output(Bytecode     * pBytecode,
                   std::string    sSourceCharset,
                   std::string    sDestCharset)
{
	using namespace CTPP;

	// Run virtual machine
	UINT_32     iIP = 0;
	try
	{
		std::string sResult;

		if (bUseRecoder)
		{
			if (sSourceCharset.empty()) { sSourceCharset = sSrcEnc; }
			if (sDestCharset.empty())   { sDestCharset   = sDstEnc; }
		}

		if (!sSourceCharset.empty() && !sDestCharset.empty())
		{
			StringIconvOutputCollector oOutputCollector(sResult, sSourceCharset, sDestCharset, 3);
			pVM -> Init(oOutputCollector, *(pBytecode -> pVMMemoryCore));
			pVM -> Run(*(pBytecode -> pVMMemoryCore), iIP, *pCDT);
		}
		else
		{
			StringOutputCollector oOutputCollector(sResult);
			pVM -> Init(oOutputCollector, *(pBytecode -> pVMMemoryCore));
			pVM -> Run(*(pBytecode -> pVMMemoryCore), iIP, *pCDT);
		}

		return newSVpv(sResult.data(), sResult.length());
	}
	catch (ZeroDivision           & e) { oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_ZERO_DIVISION_ERROR,           VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP()); }
	catch (ExecutionLimitReached  & e) { oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_EXECUTION_LIMIT_REACHED_ERROR, VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP()); }
	catch (CodeSegmentOverrun     & e) { oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_CODE_SEGMENT_OVERRUN_ERROR,    VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP()); }
	catch (InvalidSyscall         & e)
	{
		if (e.GetIP() != 0)
		{
			oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_INVALID_SYSCALL_ERROR,         VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP());
		}
		else
		{
			oCTPPError = CTPPError(e.GetSourceName(), std::string("Unsupported syscall: \"") + e.what() + "\"", CTPP_VM_ERROR | CTPP_INVALID_SYSCALL_ERROR,         VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP());
		}
	}
	catch (IllegalOpcode          & e) { oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_ILLEGAL_OPCODE_ERROR,          VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP()); }
	catch (StackOverflow          & e) { oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_STACK_OVERFLOW_ERROR,          VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP()); }
	catch (StackUnderflow         & e) { oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_STACK_UNDERFLOW_ERROR,         VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP()); }
	catch (VMException            & e) { oCTPPError = CTPPError(e.GetSourceName(), e.what(), CTPP_VM_ERROR | CTPP_VM_GENERIC_ERROR,              VMDebugInfo(e.GetDebugInfo()).GetLine(), VMDebugInfo(e.GetDebugInfo()).GetLinePos(), e.GetIP()); }
	catch (CTPPUnixException      & e) { oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | CTPP_UNIX_ERROR,                    0, 0, iIP); }
	catch (CDTRangeException      & e) { oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | CTPP_RANGE_ERROR,                   0, 0, iIP); }
	catch (CDTAccessException     & e) { oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | CTPP_ACCESS_ERROR,                  0, 0, iIP); }
	catch (CDTTypeCastException   & e) { oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | CTPP_TYPE_CAST_ERROR,               0, 0, iIP); }
	catch (CTPPLogicError         & e) { oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | CTPP_LOGIC_ERROR,                   0, 0, iIP); }

	catch(CTPPCharsetRecodeException &e)
	{
		oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | CTPP_CHARSET_RECODE_ERROR, 0, 0, 0);
	}

	catch (CTPPException          & e) { oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | CTPP_UNKNOWN_ERROR,                 0, 0, iIP); }
	catch (std::exception         & e) { oCTPPError = CTPPError("", e.what(), CTPP_VM_ERROR | STL_UNKNOWN_ERROR,                  0, 0, iIP); }
	catch (...)                        { oCTPPError = CTPPError("", "Unknown Error", CTPP_VM_ERROR | STL_UNKNOWN_ERROR,           0, 0, iIP); }

	// Error occured
	if (oCTPPError.line != 0)
	{
		warn("output(): %s (error code 0x%08X); IP: 0x%08X, file %s line %d pos %d", oCTPPError.error_descr.c_str(),
		                                                                             oCTPPError.error_code,
		                                                                             oCTPPError.ip,
		                                                                             oCTPPError.template_name.c_str(),
		                                                                             oCTPPError.line,
		                                                                             oCTPPError.pos);
	}
	else
	{
		warn("output(): %s (error code 0x%08X); IP: 0x%08X", oCTPPError.error_descr.c_str(),
		                                                     oCTPPError.error_code,
		                                                     oCTPPError.ip);
	}
return newSVpv("", 0);
}

//
// Include directories
//
int CTPP2::include_dirs(SV * aIncludeDirs)
{
	if (SvTYPE(aIncludeDirs) == SVt_RV) { aIncludeDirs = SvRV(aIncludeDirs); }

	if (SvTYPE(aIncludeDirs) != SVt_PVAV)
	{
		oCTPPError = CTPPError("", "ERROR in include_dirs(): Only ARRAY of strings accepted", CTPP_DATA_ERROR | CTPP_LOGIC_ERROR, 0, 0, 0);
		warn("ERROR in include_dirs(): Only ARRAY of strings accepted");
		return -1;
	}

	AV * pArray = (AV *)(aIncludeDirs);
	I32 iArraySize = av_len(pArray);

	std::vector<std::string> vTMP;

	for(I32 iI = 0; iI <= iArraySize; ++iI)
	{
		SV ** pArrElement = av_fetch(pArray, iI, FALSE);
		SV *  pElement = *pArrElement;

		if (SvTYPE(pElement) != SVt_PV)
		{
			CHAR_8 szTMPBuf[1024 + 1];
			snprintf(szTMPBuf, 1024, "ERROR in include_dirs(): Need STRING at array index %d", iI);
			oCTPPError = CTPPError("", szTMPBuf, CTPP_DATA_ERROR | CTPP_LOGIC_ERROR, 0, 0, 0);
			warn(szTMPBuf);
			return -1;
		}

		if (SvPOK(pElement))
		{
			STRLEN iLen;
#ifdef SvPV_const // More effcetive way to get values
			const char * szValue = SvPV_const(pElement, iLen);
#else
			char * szValue = SvPV(pElement, iLen);
#endif
			vTMP.push_back(std::string(szValue, iLen));
		}
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
	catch (CTPPUnixException      & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_UNIX_ERROR,                    0, 0, 0); }
	catch (CDTRangeException      & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_RANGE_ERROR,                   0, 0, 0); }
	catch (CDTAccessException     & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_ACCESS_ERROR,                  0, 0, 0); }
	catch (CDTTypeCastException   & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_TYPE_CAST_ERROR,               0, 0, 0); }
	catch (CTPPLogicError         & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_LOGIC_ERROR,                   0, 0, 0); }
	catch (CTPPException          & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | CTPP_UNKNOWN_ERROR,                 0, 0, 0); }
	catch (std::exception         & e) { oCTPPError = CTPPError("", e.what(), CTPP_DATA_ERROR | STL_UNKNOWN_ERROR,                  0, 0, 0); }
	catch (...)                        { oCTPPError = CTPPError("", "Unknown Error", CTPP_DATA_ERROR | STL_UNKNOWN_ERROR,           0, 0, 0); }

	// Error occured
	warn("load_bytecode(): %s (error code 0x%08X); IP: 0x%08X", oCTPPError.error_descr.c_str(),
	                                                     oCTPPError.error_code,
	                                                     oCTPPError.ip);

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
	catch (CTPPParserSyntaxError        & e)
	{
		oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | CTPP_SYNTAX_ERROR, e.GetLine(), e.GetLinePos(), 0);
	}
	catch (CTPPParserOperatorsMismatch  & e)
	{
		oCTPPError = CTPPError(szFileName, std::string("Expected ") + e.Expected() + ", but found " + e.Found(), CTPP_COMPILER_ERROR | CTPP_SYNTAX_ERROR, e.GetLine(), e.GetLinePos(), 0);
	}
	catch (CTPPUnixException            & e) { oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | CTPP_UNIX_ERROR,                    0, 0, 0); }
	catch (CDTRangeException            & e) { oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | CTPP_RANGE_ERROR,                   0, 0, 0); }
	catch (CDTAccessException           & e) { oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | CTPP_ACCESS_ERROR,                  0, 0, 0); }
	catch (CDTTypeCastException         & e) { oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | CTPP_TYPE_CAST_ERROR,               0, 0, 0); }
	catch (CTPPLogicError               & e) { oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | CTPP_LOGIC_ERROR,                   0, 0, 0); }
	catch (CTPPException                & e) { oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | CTPP_UNKNOWN_ERROR,                 0, 0, 0); }
	catch (std::exception               & e) { oCTPPError = CTPPError(szFileName, e.what(), CTPP_COMPILER_ERROR | STL_UNKNOWN_ERROR,                  0, 0, 0); }
	catch (...)                              { oCTPPError = CTPPError(szFileName, "Unknown Error", CTPP_COMPILER_ERROR | STL_UNKNOWN_ERROR,           0, 0, 0); }

	// Error occured
	warn("parse_template(): In file %s at line %d, pos %d: %s (error code 0x%08X)", oCTPPError.template_name.c_str(),
	                                                                                oCTPPError.line,
	                                                                                oCTPPError.pos,
	                                                                                oCTPPError.error_descr.c_str(),
	                                                                                oCTPPError.error_code);

return NULL;
}

//
// Parse template
//
Bytecode * CTPP2::parse_text(SV * sText)
{
	using namespace CTPP;
	try
	{
		return new Bytecode(sText, vIncludeDirs);
	}
	catch (CTPPParserSyntaxError        & e)
	{
		oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | CTPP_SYNTAX_ERROR, e.GetLine(), e.GetLinePos(), 0);
	}
	catch (CTPPParserOperatorsMismatch  & e)
	{
		oCTPPError = CTPPError("direct source", std::string("Expected ") + e.Expected() + ", but found " + e.Found(), CTPP_COMPILER_ERROR | CTPP_SYNTAX_ERROR, e.GetLine(), e.GetLinePos(), 0);
	}
	catch (CTPPUnixException            & e) { oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | CTPP_UNIX_ERROR,                    0, 0, 0); }
	catch (CDTRangeException            & e) { oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | CTPP_RANGE_ERROR,                   0, 0, 0); }
	catch (CDTAccessException           & e) { oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | CTPP_ACCESS_ERROR,                  0, 0, 0); }
	catch (CDTTypeCastException         & e) { oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | CTPP_TYPE_CAST_ERROR,               0, 0, 0); }
	catch (CTPPLogicError               & e) { oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | CTPP_LOGIC_ERROR,                   0, 0, 0); }
	catch (CTPPException                & e) { oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | CTPP_UNKNOWN_ERROR,                 0, 0, 0); }
	catch (std::exception               & e) { oCTPPError = CTPPError("direct source", e.what(), CTPP_COMPILER_ERROR | STL_UNKNOWN_ERROR,                  0, 0, 0); }
	catch (...)                              { oCTPPError = CTPPError("direct source", "Unknown Error", CTPP_COMPILER_ERROR | STL_UNKNOWN_ERROR,           0, 0, 0); }

	// Error occured
	warn("parse_template(): In file %s at line %d, pos %d: %s (error code 0x%08X)", oCTPPError.template_name.c_str(),
	                                                                                oCTPPError.line,
	                                                                                oCTPPError.pos,
	                                                                                oCTPPError.error_descr.c_str(),
	                                                                                oCTPPError.error_code);

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

//
// Get last error description
//
SV * CTPP2::get_last_error()
{
	HV * pRetVal = newHV();

	hv_store_ent(pRetVal, newSVpvf("%s", "template_name"), newSVpv(oCTPPError.template_name.c_str(), oCTPPError.template_name.size()), 0);
	hv_store_ent(pRetVal, newSVpvf("%s", "line"         ), newSViv(oCTPPError.line), 0);
	hv_store_ent(pRetVal, newSVpvf("%s", "pos"          ), newSViv(oCTPPError.pos), 0);
	hv_store_ent(pRetVal, newSVpvf("%s", "ip"           ), newSViv(oCTPPError.ip), 0);
	hv_store_ent(pRetVal, newSVpvf("%s", "error_code"   ), newSViv(oCTPPError.error_code), 0);
	hv_store_ent(pRetVal, newSVpvf("%s", "error_str"    ), newSVpv(oCTPPError.error_descr.c_str(), oCTPPError.error_descr.size()), 0);

return newRV_noinc((SV*) pRetVal);
}

// Bytecode Implementation /////////////////////////////////////

//
// Constructor
//
Bytecode::Bytecode(SV * sText, const std::vector<std::string> & vIncludeDirs): pCore(NULL), pVMMemoryCore(NULL)
{
	using namespace CTPP;

	if (!SvPOK(sText)) { throw CTPPLogicError("Cannot template source"); }

	STRLEN iLen;
#ifdef SvPV_const // More effcetive way to get values
	const char * szValue = SvPV_const(sText, iLen);
#else
	char * szValue = SvPV(sText, iLen);
#endif

	// Load template
	CTPP2TextSourceLoader oSourceLoader(std::string(szValue, iLen));
	oSourceLoader.SetIncludeDirs(vIncludeDirs);

	// Compiler runtime
	VMOpcodeCollector  oVMOpcodeCollector;
	StaticText         oSyscalls;
	StaticData         oStaticData;
	StaticText         oStaticText;
	HashTable          oHashTable;
	CTPP2Compiler oCompiler(oVMOpcodeCollector, oSyscalls, oStaticData, oStaticText, oHashTable);

	// Create template parser
	CTPP2Parser oCTPP2Parser(&oSourceLoader, &oCompiler, "direct source");

	// Compile template
	oCTPP2Parser.Compile();

	// Get program core
	UINT_32 iCodeSize = 0;
	const VMInstruction * oVMInstruction = oVMOpcodeCollector.GetCode(iCodeSize);

	// Dump program
	VMDumper oDumper(iCodeSize, oVMInstruction, oSyscalls, oStaticData, oStaticText, oHashTable);
	const VMExecutable * aProgramCore = oDumper.GetExecutable(iCoreSize);

	// Allocate memory
	pCore = (VMExecutable *)malloc(iCoreSize);
	memcpy(pCore, aProgramCore, iCoreSize);
	pVMMemoryCore = new VMMemoryCore(pCore);
//fprintf(stderr, "pCore = %p, pVMMemoryCore = %p\n", pCore, pVMMemoryCore);
}

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
		HashTable          oHashTable;
		CTPP2Compiler oCompiler(oVMOpcodeCollector, oSyscalls, oStaticData, oStaticText, oHashTable);

		// Create template parser
		CTPP2Parser oCTPP2Parser(&oSourceLoader, &oCompiler, szFileName);

		// Compile template
		oCTPP2Parser.Compile();

		// Get program core
		UINT_32 iCodeSize = 0;
		const VMInstruction * oVMInstruction = oVMOpcodeCollector.GetCode(iCodeSize);

		// Dump program
		VMDumper oDumper(iCodeSize, oVMInstruction, oSyscalls, oStaticData, oStaticText, oHashTable);
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
	delete pVMMemoryCore;
	free(pCore);
}

// /////////

//
// Constructor
//
CTPP2TextSourceLoader::CTPP2TextSourceLoader(const std::string & sITemplate): sTemplate(sITemplate)
{
	;;
}

//
// Set include directories
//
void CTPP2TextSourceLoader::SetIncludeDirs(const std::vector<std::string> & vIIncludeDirs) { return oFileLoader.SetIncludeDirs(vIIncludeDirs); }

//
// Load template with specified name
//
INT_32 CTPP2TextSourceLoader::LoadTemplate(CCHAR_P szTemplateName) { return oFileLoader.LoadTemplate(szTemplateName); }

//
// Get template
//
CCHAR_P CTPP2TextSourceLoader::GetTemplate(UINT_32 & iTemplateSize)
{
	iTemplateSize = sTemplate.size();

return sTemplate.data();
}

//
// Clone loader object
//
CTPP::CTPP2SourceLoader * CTPP2TextSourceLoader::Clone() { return oFileLoader.Clone(); }

//
// A destructor
//
CTPP2TextSourceLoader::~CTPP2TextSourceLoader() throw()
{
	;;
}

MODULE = HTML::CTPP2		PACKAGE = HTML::CTPP2

CTPP2 *
CTPP2::new(...)
    CODE:
	UINT_32 iArgStackSize  = 10240;
	UINT_32 iCodeStackSize = 10240;
	UINT_32 iStepsLimit    = 1048576;
	UINT_32 iMaxFunctions  = 1024;
	std::string sSrcEnc;
	std::string sDstEnc;

	if (items % 2 != 1)
	{
		croak("ERROR: new HTML::CTPP2() called with odd number of option parameters - should be of the form option => value");
	}

	for (INT_32 iI = 1; iI < items; iI+=2)
	{
		STRLEN iKeyLen = 0;
		STRLEN iValLen = 0;
#ifdef SvPV_const
		const char * szKey   = NULL;
		const char * szValue = NULL;
#else
		char * szKey   = NULL;
		char * szValue = NULL;
#endif

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
#ifdef SvPV_const // More effcetive way to get values
				szKey = SvPV_const(ST(iI), iKeyLen);
#else
				szKey = SvPV(ST(iI), iKeyLen);
#endif
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
#ifdef SvPV_const // More effcetive way to get values
				szValue = SvPV_const(ST(iI + 1), iValLen);
#else
				szValue = SvPV(ST(iI + 1), iValLen);
#endif
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
		else if (strncasecmp("source_charset", szKey, iKeyLen) == 0)
		{
			sSrcEnc = szValue;
		}
		else if (strncasecmp("destination_charset", szKey, iKeyLen) == 0)
		{
			sDstEnc = szValue;
		}
		else
		{
			croak("ERROR: Unknown parameter name: `%s`", szKey);
		}
	}
	RETVAL = new CTPP2(iArgStackSize, iCodeStackSize, iStepsLimit, iMaxFunctions, sSrcEnc, sDstEnc);
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

int
CTPP2::json_param(SV * pParams)

SV *
CTPP2::output(...)
    CODE:
	Bytecode     * pBytecode = NULL;
	std::string    sSrcEnc;
	std::string    sDstEnc;

	if (items != 2 && items != 4)
	{
		croak("ERROR: should be called as output($bytecode) or output($bytecode, $src_charset, $dst_charset)");
	}

	if( sv_isobject(ST(1)) && (SvTYPE(SvRV(ST(1))) == SVt_PVMG) )
	{
		pBytecode = (Bytecode *)SvIV((SV*)SvRV( ST(1) ));
	}
	else
	{
		warn( "HTML::CTPP2::output($bytecode ... -- $bytecode is not a blessed SV reference" );
		XSRETURN_UNDEF;
	};

	if (items == 4)
	{
		STRLEN        iKeyLen = 0;
		const char  * szKey   = NULL;

		if (SvPOK(ST(2)))
		{
#ifdef SvPV_const // More effcetive way to get values
			szKey = SvPV_const(ST(2), iKeyLen);
#else
			szKey = SvPV(ST(2), iKeyLen);
#endif
		}
		if (szKey == NULL || iKeyLen == 0) { croak("ERROR: incorrect source encoding"); }
		sSrcEnc.assign(szKey, iKeyLen);

		iKeyLen = 0;
		if (SvPOK(ST(3)))
		{
#ifdef SvPV_const // More effcetive way to get values
			szKey = SvPV_const(ST(3), iKeyLen);
#else
			szKey = SvPV(ST(3), iKeyLen);
#endif
		}
		if (szKey == NULL || iKeyLen == 0) { croak("ERROR: incorrect destination encoding"); }
		sDstEnc.assign(szKey, iKeyLen);
	}
	RETVAL = THIS -> output(pBytecode, sSrcEnc, sDstEnc);
    OUTPUT:
	RETVAL

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
CTPP2::parse_text(SV * sTemplate)
    CODE:
        Bytecode * pBytecode = THIS -> parse_text(sTemplate);
        ST(0) = sv_newmortal();
        sv_setref_pv( ST(0), "HTML::CTPP2::Bytecode", (void*)pBytecode );
        XSRETURN(1);

SV *
CTPP2::dump_params()

SV *
CTPP2::get_last_error()

MODULE = HTML::CTPP2		PACKAGE = HTML::CTPP2::Bytecode

int
Bytecode::save(char * szFileName)

void
Bytecode::DESTROY()

namespace Shell.PlatformWin;

using System;

static class NativeImm32
{
	[Import("IMM32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public void* ImmGetContext(void* hWnd);

	[Import("IMM32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ImmReleaseContext(void* hWnd, void* hIMC);

	[Import("IMM32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ImmGetCompositionStringW(void* hIMC, uint32 dwIndex, void* lpBuf, uint32 dwBufLen);

	[Import("IMM32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ImmSetCompositionWindow(void* hIMC, COMPOSITIONFORM* lpCompForm);

	[Import("IMM32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ImmSetCandidateWindow(void* hIMC, CANDIDATEFORM* lpCandidate);

	[Import("IMM32.lib"), CLink, CallingConvention(.Stdcall)]
	extern static public int32 ImmNotifyIME(void* hIMC, uint32 dwAction, uint32 dwIndex, uint32 dwValue);
}

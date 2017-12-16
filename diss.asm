;Donatas Tamosauskas Programu sistemos IV gr.
;Disasembleris 2017-11-13
;
; Working style:
;
; 0. Read a byte
; 1. Check if end of file
; 2. Check if it is a prefix
; 3. If not prefix, check if it can be recognised as a command
;   3.1. If not a command, print "Unrecogized command."
;	3.2. If a command, then call that command's procedure
; 5. Go back to step 0


.model small

.stack 100h

.data
	inputFilename db 20 dup(0) 
	outputFilename db 20 
	inputFileDescriptor dw ?
	outputFileDescriptor dw ?
	adressOfString dw ?
	rByte db ?
	adrMod db ?
	adrReg db ?
	adrRM db ?
	adrDW db ?	
	opNameOffset dw ?
	opArg1Offset dw ?
	opArg2Offset dw ?
	prefix db 0
	jump db 0
	prefixValue dw 0009 ; 0 - ES, 3 - CS, 6 -  SS, 9 - DS
	
	newLine db 0Dh, 0Ah, "$"
	spaceSemicolon db ", $"
	
	pre26 db "ES$"
	pre2E db "CS$"
	pre36 db "SS$"
	pre3E db "DS$"
	
	reg000 db "AL$"
	reg001 db "CL$"
	reg010 db "DL$"
	reg011 db "BL$"
	reg100 db "AH$"
	reg101 db "CH$"
	reg110 db "DH$"
	reg111 db "BH$"
	
	regW000 db "AX$"
	regW001 db "CX$"
	regW010 db "DX$"
	regW011 db "BX$"
	regW100 db "SP$"
	regW101 db "BP$"
	regW110 db "SI$"
	regW111 db "DI$"
	
	regMod000 db "BX + SI $"
	regMod001 db "BX + DI $"
	regMod010 db "BP + SI $"
	regMod011 db "BP + DI $"
	regMod100 db "SI $$$$$$"
	regMod101 db "DI $$$$$$"
	regMod110 db "$$$$$$$$$"
	regMod111 db "BX $$$$$$"
	
	opNameJO  db "JO  $"
	opNameJB  db "JB  $"
	opNameJAE db "JAE $"
	opNameJE  db "JE  $"
	opNameJNE db "JNE $"
	opNameJBE db "JBE $"
	opNameJA  db "JA  $"
	opNameJS  db "JS  $"	
	opNameJNS db "JNS $"
	opNameJP  db "JP  $"
	opNameJNP db "JNP $"
	opNameJL  db "JL  $"
	opNameJGE db "JGE $"
	opNameJLE db "JLE $"
	opNameJG  db "JG  $"
	opNameJCXZ db "JCXZ $"
	
	opNameADD db "ADD $"
	opNamePOP db "POP $"
	opNameSUB db "SUB $"
	opNameCMP db "CMP $"
	opNameINC db "INC $"
	opNameDEC db "DEC $"
	opNameMOV db "MOV $"
	opNameRET db "RET $"
	opNameJMP db "JMP $"
	opNameMUL db "MUL $"
	opNameDIV db "DIV $"
	opNameINT db "INT $"
	opNameSHL db "SHL $"
	opNameLOOP db "LOOP $"
	opNameCALL db "CALL $"
	opNamePUSH db "PUSH $"	
	opNameIFJUMP db "Some jump $"
	opNameADDSUBCMP db "ADD/SUB/CMP $"
	opNameUNRECOGNIZED db "Unrecogized command. $"
	
	errorMessageText db "Error in filenames.$"
	
	bytePtr db "byte ptr $"
	wordPtr db "word ptr $"
	onlyPtr db "ptr $"
	
	writeBufferSize dw 0
	writeBuffer db 100	
	
.code	

	ReadParameters proc ;reads parameters for inputFilename, outputFilename
		push ax
		push bx
		push dx		
		mov bx, 0000h
		mov di, 00h		
		InputParamLoop:
			mov al, es:[82h + bx]			
			inc bx
			cmp al, ' ' ; palygina su tarpu
			je BeginOutputRead
			mov offset [inputFilename + di], al
			inc di
			jmp InputParamLoop			
		BeginOutputRead:
		mov si, 0000h		
		OutputParamLoop:
			mov al, byte ptr es:[82h + bx]			
			inc bx
			mov [outputFilename + si], al			
			inc si
			cmp bl, byte ptr es:[80h] ; palygina su pabaigos
			jne OutputParamLoop
		dec si
		mov [outputFilename + si], 00h
		pop dx
		pop bx
		pop ax
		ret
		ErrorMessage:		
			mov ah, 02h
			mov dl, 0Ah
			int 21h
		
			mov ah, 09h
			mov dx, offset errorMessageText
			int 21h
			jmp Ending			
	ReadParameters endp
	
	OpenInput proc
		mov ax, 3D00h
		mov dx, offset inputFilename
		int 21h		
		jc ErrorMessage
		mov inputFileDescriptor, ax
		ret
	OpenInput endp
	
	CreateOutput proc
		mov ah, 3Ch
		mov cx, 0080h
		mov dx, offset outputFilename
		int 21h
		jc ErrorMessage		
		mov outputFileDescriptor, ax		
		ret
	CreateOutput endp
	
	SaveSymbolToWriteBuffer proc ; copies symbol from dl to writeBuffer
		mov si, writeBufferSize		
		mov [writeBuffer + si], dl
		inc writeBufferSize
		ret
	SaveSymbolToWriteBuffer endp ; copies string from ds:dx to writeBuffer
	
	SaveStringToWriteBuffer proc
		push dx
		mov di, dx
		mov si, writeBufferSize
		copyLoop:
			mov dl, byte ptr ds:[di]			
			cmp dl, '$'
			je endCopy			
			mov [writeBuffer + si], dl		
			inc si
			inc di			
			jmp copyLoop
		endCopy:
		mov writeBufferSize, si
		pop dx
		ret
	SaveStringToWriteBuffer endp
	
	WriteBufferToFile proc
		push ax bx cx dx
		;call CloseFile
		mov ah, 40h
		mov cx, writeBufferSize
		mov dx , offset writeBuffer
		mov bx, outputFileDescriptor
		int 21h ; write to file
		mov writeBufferSize, 00h
		pop dx cx bx ax
		ret
	WriteBufferToFile endp	

	CloseFile proc
		mov ah, 3Eh
		int 21h ; close file
		ret
	CloseFile endp
	
	ReadByte proc ;reads one byte and puts it into rByte
		push ax bx cx
		mov bx, ds:[inputFileDescriptor]		
		mov ah, 3Fh
		mov cx, 0001h ; reads one byte
		mov dx, offset rByte
		int 21h		
		cmp ax, 00h ; 0 bytes read
		jne notEOF
			jmp Ending
		notEOF:		
		pop cx bx ax
		ret
	ReadByte endp
	
	PrintSymbol proc ;prints symbol in dl
		push ax		
		mov ah, 02h
		int 21h		
		call SaveSymbolToWriteBuffer
		pop ax
		ret
	PrintSymbol endp
	
	PrintString proc ;prints string with offset DX
		push ax
		mov ah, 09h
		int 21h
		call SaveStringToWriteBuffer
		pop ax
		ret	
	PrintString endp
	
	PrintNewLine proc ; prints new line
		push dx
		mov dx, offset newLine
		call PrintString
		pop dx
		ret
	PrintNewLine endp
	
	PrintSemicolonSpace proc ; prints semicolon and space
		push dx
		mov dx, offset spaceSemicolon
		call PrintString
		pop dx
		ret
	PrintSemicolonSpace endp
	
	PrintCommaBracket proc ; prints ":["
		push dx
		mov dl, ':'
		call PrintSymbol
		mov dl, '['
		call PrintSymbol
		pop dx
		ret
	PrintCommaBracket endp	
	
	PrintBracket proc ; prints "]"
		push dx
		mov dl, ']'
		call PrintSymbol
		pop dx
		ret
	PrintBracket endp
		
	PrintPlusWithSpace proc ; prints "+ "
		mov dl, "+"
		call PrintSymbol
		mov dl, " "
		call PrintSymbol
		ret
	PrintPlusWithSpace endp
	
	PrintH proc ; prints letter "h"
		push dx
		mov dl, 'h'
		call PrintSymbol
		pop dx
		ret
	PrintH endp
	
	PrintHexNumber proc ; Prints HEX byte in dl
		push ax
		push cx
		mov ah, 00h
		mov al, dl
		mov cx, 0002h
		mov dl, 10h
		div dl
		PrintLoop:				
			cmp al, 9
			ja letter
			add al, 30h
			mov dl, al
			call PrintSymbol
			jmp PrintHexEnd
			letter:
			add al, 37h
			mov dl, al
			call PrintSymbol
			PrintHexEnd:
			mov al, ah				
		loop PrintLoop
		pop cx
		pop ax
		ret
	PrintHexNumber endp
		
	PrintNextOneByte proc ; reads and prints next byte and letter "h"
		push dx
		call ReadByte
		mov dl, rByte
		call PrintHexNumber
		call PrintH
		pop dx	
		ret
	PrintNextOneByte endp	
	
	PrintNextTwoBytes proc ; reads and prints next two bytes and letter "h"
		push dx		
		call ReadByte
		mov dl, rByte
		mov [rByte + 1], dl
		call ReadByte
		mov dl, rByte
		call PrintHexNumber
		mov dl, [rByte + 1]
		call PrintHexNumber
		call PrintH
		pop dx
		ret
	PrintNextTwoBytes endp
	
	PrintRegValueFromOP macro buffer ; prints reg. with offset from rByte's last 3 bits
		mov ah, 00h
		mov al, rByte
		and al, 00000111b
		mov dl, 3h
		mul dl		
		mov dx, offset buffer
		mov ah, 00h
		add dx, ax
		call PrintString
	endm
	
	PrintSegRegValueFromOP macro ; prints seg. reg. with offset from rByte's 2 bits
		mov ah, 00h
		mov al, rByte
		and al, 00011000b
		mov dl, 1000b
		div dl
		mov dl, 3h
		mul dl		
		mov dx, offset pre26
		mov ah, 00h
		add dx, ax
		call PrintString
	endm
	
	unknownOpperand macro buffer ; checks if buffer is below al
		local notUnknown
		cmp al, buffer
		jae notUnknown
		jmp unrecognizedOp
		notUnknown:
	endm
	
	acumulatorAndOp proc 
		push dx
		mov dh, 00h
		mov dl, rByte
		and dl, 1b
		cmp dl, 1b
		je isWord
			mov dx, offset reg000; w = 0
			call PrintString
			call PrintSemicolonSpace			
			call PrintNextOneByte	
			jmp acumulatorAndOpEnding
		isWord: ; w = 1
			mov dx, offset regW000; w = 1
			call PrintString
			call PrintSemicolonSpace			
			call PrintNextTwoBytes	
		acumulatorAndOpEnding:
		pop dx
		ret
	acumulatorAndOp endp
	
	AnalyzeAdressingByte proc ; puts apropriate values in adrDW, adrMod, adrReg, adrRM
		push ax
		push dx
			mov ah, 00h
			mov al, rByte
			mov dl, 100b
			div dl
			mov adrDW, ah ; adrDW		
		call ReadByte
		mov ah, 00h
			mov al, rByte
			mov dl, 00001000b 
			div dl
			mov adrRM, ah ; adrRM
		mov ah, 00h
			div dl
			mov adrReg, ah ; adrReg
		mov dl, 100b
			mov ah, 00h 
			div dl
			mov adrMod, ah ; adrMod
		pop dx
		pop ax
		ret
	AnalyzeAdressingByte endp
	
	PrintByteWordPtrAndMemory proc ; Takes byte/word ptr adress from dx
		cmp jump, 00h
		ja isJump
			call PrintString
		isJump:
		call PrintPrefixDefaultDS
		cmp adrRM, 110b
		je direct1
		mov ah, 00h
		mov al, adrRM
		mov dx, 0009h
		mul dl
		mov dx, ax
		add dx, offset regMod000
		call PrintString
		jmp endDirect1
		direct1:
		call PrintNextTwoBytes
		endDirect1:
		ret
	PrintByteWordPtrAndMemory endp
	
	PrintRegValueByte proc
		mov ah, 00h
		mov al, adrReg
		mov dx, 0003h
		mul dl
		mov dx, ax
		add dx, offset reg000
		call PrintString
		ret
	PrintRegValueByte endp
	
	PrintRegValueByteFromRM proc
		mov ah, 00h
		mov al, adrRM
		mov dx, 0003h
		mul dl
		mov dx, ax
		add dx, offset reg000
		call PrintString
		ret
	PrintRegValueByteFromRM endp
	
	PrintRegValueWord proc
		mov ah, 00h
		mov al, adrReg
		mov dx, 0003h
		mul dl
		mov dx, ax
		add dx, offset regW000
		call PrintString
		ret
	PrintRegValueWord endp
	
	PrintRegValueWordFromRM proc
		mov ah, 00h
		mov al, adrRM
		mov dx, 0003h
		mul dl
		mov dx, ax
		add dx, offset regW000
		call PrintString
		ret
	PrintRegValueWordFromRM endp

	PrintPrefixDefaultDS proc ; prints ds:[, or any other prefix that is stated
		push dx
		cmp prefix, 00h
		ja notDSPrefix
			mov dx, offset pre3E
			jmp endPrintPrefixDefaultDS
		notDSPrefix:
			mov dx, offset pre26
			add dx, prefixValue
			mov prefix, 00h
		endPrintPrefixDefaultDS:	
		call PrintString
		call PrintCommaBracket
		pop dx
		ret
	PrintPrefixDefaultDS endp
	
	PrintModRegRM proc
		push ax
		push dx
		cmp adrMod, 00b
		ja notMod00			
			cmp adrDW, 0000b
			ja notDW001
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintBracket
			call PrintSemicolonSpace
			call PrintRegValueByte	
			jmp endDW1
			
			notDW001:
			cmp adrDW, 0001b
			ja notDW011
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintBracket
			call PrintSemicolonSpace
			call PrintRegValueWord	
			jmp endDW1
			
			notDW011:
			cmp adrDW, 0010b
			ja notDW101
			call PrintRegValueByte
			call PrintSemicolonSpace
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintBracket
			jmp endDW1
			
			notDW101:
			cmp adrDW, 0011b
			ja endDW1
			call PrintRegValueWord
			call PrintSemicolonSpace
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintBracket
			endDW1:
		jmp endPrintRegMod
		notMod00:	
		
		cmp adrMod, 0001b
		ja notMod01			
			cmp adrDW, 0000b
			ja notDW002
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextOneByte
			call PrintBracket
			call PrintSemicolonSpace
			call PrintRegValueByte	
			jmp endDW2
			
			notDW002:
			cmp adrDW, 0001b
			ja notDW012
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextOneByte
			call PrintBracket
			call PrintSemicolonSpace
			call PrintRegValueWord	
			jmp endDW2
			
			notDW012:
			cmp adrDW, 0010b
			ja notDW102
			call PrintRegValueByte
			call PrintSemicolonSpace
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextOneByte
			call PrintBracket
			jmp endDW2
			
			notDW102:
			cmp adrDW, 0011b
			ja endDW2
			call PrintRegValueWord
			call PrintSemicolonSpace
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextOneByte
			call PrintBracket
			endDW2:
		jmp endPrintRegMod
		notMod01:
		
		cmp adrMod, 0010b
		ja notMod10			
			cmp adrDW, 0000b
			ja notDW003
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextTwoBytes
			call PrintBracket
			call PrintSemicolonSpace
			call PrintRegValueByte	
			jmp endDW3
			
			notDW003:
			cmp adrDW, 0001b
			ja notDW013
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextTwoBytes
			call PrintBracket
			call PrintSemicolonSpace
			call PrintRegValueWord	
			jmp endDW3
			
			notDW013:
			cmp adrDW, 0010b
			ja notDW103
			call PrintRegValueByte
			call PrintSemicolonSpace
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextTwoBytes
			call PrintBracket
			jmp endDW3
			
			notDW103:
			cmp adrDW, 0011b
			ja endDW3
			call PrintRegValueWord
			call PrintSemicolonSpace
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextTwoBytes
			call PrintBracket
			endDW3:
		jmp endPrintRegMod
		notMod10:
				
			cmp adrDW, 0000b
			ja notDW004
			call PrintRegValueByteFromRM
			call PrintSemicolonSpace
			call PrintRegValueByte	
			jmp endDW4
			
			notDW004:
			cmp adrDW, 0001b
			ja notDW014
			call PrintRegValueWordFromRM
			call PrintSemicolonSpace
			call PrintRegValueWord	
			jmp endDW4
			
			notDW014:
			cmp adrDW, 0010b
			ja notDW104
			call PrintRegValueByte
			call PrintSemicolonSpace
			call PrintRegValueByteFromRM
			jmp endDW4
			
			notDW104:
			cmp adrDW, 0011b
			ja endDW4
			call PrintRegValueWord
			call PrintSemicolonSpace
			call PrintRegValueWordFromRM
			endDW4:		
		endPrintRegMod:
		pop dx
		pop ax
		ret
	PrintModRegRM endp
	
	PrintModOpkRM proc 
		push ax
		push dx
		mov al, adrDW
		and al, 0001b
		
		cmp adrMod, 0000b
		ja notMod001			
			cmp al, 0b
			ja notSW01
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintBracket
			jmp endPrintModOpkRMWithImmediate1			
			notSW01:			
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintBracket			
		jmp endPrintModOpkRMWithImmediate1
		notMod001:

		cmp adrMod, 0001b
		ja notMod011		
			cmp al, 0b
			ja notSW02
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextOneByte
			call PrintBracket
			jmp endPrintModOpkRMWithImmediate1	
			notSW02:			
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextOneByte	
			call PrintBracket
		jmp endPrintModOpkRMWithImmediate1
		notMod011:
		
		cmp adrMod, 0010b
		ja notMod101		
			cmp al, 0b
			ja notSW03
			mov dx, offset bytePtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextTwoBytes
			call PrintBracket
			jmp endPrintModOpkRMWithImmediate1		
			notSW03:			
			mov dx, offset wordPtr
			call PrintByteWordPtrAndMemory
			call PrintPlusWithSpace
			call PrintNextTwoBytes
			call PrintBracket
		jmp endPrintModOpkRMWithImmediate1
		notMod101:		
	
			cmp al, 0b
			ja notSW04
			call PrintRegValueByteFromRM
			jmp endPrintModOpkRMWithImmediate1			
			notSW04:			
			call PrintRegValueWordFromRM		
		endPrintModOpkRMWithImmediate1:
		pop dx
		pop ax
		ret
	PrintModOpkRM endp	
	
	AddImmediateSW proc
		push ax dx
		call PrintSemicolonSpace
		mov al, adrDW
		and al, 0011b
		cmp al, 01b
		jne notTwoBytes1
			call PrintNextTwoBytes
			jmp endPrintModOpkRMWithImmediate2
		notTwoBytes1:
			call PrintNextOneByte		
		endPrintModOpkRMWithImmediate2:
		pop dx ax
		ret
	AddImmediateSW endp
	
	AddImmediateW proc
		push ax dx
		call PrintSemicolonSpace
		mov al, adrDW
		and al, 01b
		cmp al, 00b
		ja twoBytes1
			call PrintNextOneByte			
			jmp endPrintModOpkRMWithImmediate3
		twoBytes1:
			call PrintNextTwoBytes
		endPrintModOpkRMWithImmediate3:
		pop dx ax
		ret
	AddImmediateW endp
	
	AdressWithSegReg proc
		push ax dx
		call ReadByte
		mov al, rByte		
		call ReadByte
		mov ah, rByte
		call PrintNextTwoBytes
		mov dl, ':'
		call PrintSymbol
		mov dl, '['
		call PrintSymbol
		mov dl, ah
		call PrintHexNumber
		mov dl, al
		call PrintHexNumber	
		call PrintH		
		call PrintBracket
		pop dx ax
		ret
	AdressWithSegReg endp
	
	IsPrefix proc ; if byte is a prefix, then prefix becomes 1, and prefixValue gets the byte value
		mov prefix, 01h
		cmp rByte, 26h ; was ES
		jne notES
			mov prefixValue, 00h
			jmp wasPrefix
			notES:
		cmp rByte, 2Eh ; was CS
		jne notCS
			mov prefixValue, 03h
			jmp wasPrefix
			notCS:
		cmp rByte, 36h ; was SS 
		jne notSS
			mov prefixValue, 06h
			jmp wasPrefix
			notSS:
		cmp rByte, 3Eh ; was DS
		jne notDS
			mov prefixValue, 09h
			jmp wasPrefix
			notDS:
		mov prefix, 00h
		ret
		wasPrefix:
		mov prefix, 01h
		ret
	IsPrefix endp
	
	;--------------
	ADD1 proc ; is working
		push dx	
		mov dx, offset opNameADD
		call PrintString
		call AnalyzeAdressingByte
		call PrintModRegRM		
		pop dx
		ret
	ADD1 endp
	
	ADD2 proc ; is working
		push dx
		mov dx, offset opNameADD
		call PrintString
		call acumulatorAndOp
		pop dx
		ret
	ADD2 endp
	
	PUSH1 proc ; is working
		push dx
		push ax
		mov dx, offset opNamePUSH
		call PrintString		
		PrintSegRegValueFromOP
		pop ax
		pop dx
		ret
	PUSH1 endp
	
	POP1 proc ; is working
		push dx
		mov dx, offset opNamePOP
		call PrintString
		PrintSegRegValueFromOP
		pop dx
		ret
	POP1 endp
	
	SUB1 proc ; is working
		push dx
		mov dx, offset opNameSUB
		call PrintString
		call AnalyzeAdressingByte
		call PrintModRegRM		
		pop dx
		ret
	SUB1 endp
	
	SUB2 proc ; is working
		push dx
		mov dx, offset opNameSUB
		call PrintString
		call acumulatorAndOp
		pop dx
		ret
	SUB2 endp

	CMP1 proc ; is working
		push dx
		mov dx, offset opNameCMP
		call PrintString
		call AnalyzeAdressingByte
		call PrintModRegRM		
		pop dx
		ret
	CMP1 endp
	
	CMP2 proc ; is working
		push dx 
		mov dx, offset opNameCMP
		call PrintString
		call acumulatorAndOp
		pop dx
		ret
	CMP2 endp
	
	INC1 proc ; is working
		push dx
		mov dx, offset opNameINC
		call PrintString
		PrintRegValueFromOP regW000
		pop dx
		ret
	INC1 endp
	
	DEC1 proc ; is working
		push dx
		mov dx, offset opNameDEC
		call PrintString
		PrintRegValueFromOP regW000
		pop dx
		ret
	DEC1 endp
	
	PUSH2 proc ; is working
		push dx
		mov dx, offset opNamePUSH
		call PrintString
		PrintRegValueFromOP regW000
		pop dx
		ret
	PUSH2 endp
	
	POP2 proc ; is working
		push dx
		mov dx, offset opNamePOP
		call PrintString
		PrintRegValueFromOP regW000
		pop dx
		ret
	POP2 endp
	
	IFJUMP1 proc ; is working
		push ax
		push dx
		cmp rByte, 0E3h
		je isJCXZ
		mov ah, 00h
		mov al, rByte
		sub al, 71h
		mov dl, 05h
		mul dl
		mov dx, ax		
		add dx, offset opNameJO
		jmp endIFJUMP1
		isJCXZ:
		mov dx, offset opNameJCXZ
		endIFJUMP1:
		call PrintString
		call PrintNextOneByte		
		pop dx
		pop ax
		ret
	IFJUMP1 endp
	
	ADDSUBCMP1 proc ; is working
		push dx
		call AnalyzeAdressingByte
		
		cmp adrReg, 000b
		ja notASCADD1
		mov dx, offset opNameADD
		jmp ASCEnding
		notASCADD1:
		
		cmp adrReg, 101b
		ja notASCSUB1
		mov dx, offset opNameSUB
		jmp ASCEnding
		notASCSUB1:
		
		mov dx, offset opNameCMP
		
		ASCEnding:
		call PrintString
		call PrintModOpkRM
		call AddImmediateSW
		pop dx
		ret
	ADDSUBCMP1 endp
	
	MOV1 proc ; is working 
		push dx
		mov dx, offset opNameMOV
		call PrintString
		call AnalyzeAdressingByte
		call PrintModRegRM		
		pop dx
		ret
	MOV1 endp
	
	MOV2 proc ; is working
		push dx
		mov dx, offset opNameMOV
		call PrintString
		or rByte, 0001b
		call AnalyzeAdressingByte
		cmp adrDW, 01b
		ja notSegRegRM	
			call PrintModOpkRM
			call PrintSemicolonSpace
			PrintSegRegValueFromOP
			jmp endMov2
		notSegRegRM:
			PrintSegRegValueFromOP
			call PrintSemicolonSpace
			call PrintModOpkRM
		endMov2:
		pop dx
		ret
	MOV2 endp
	
	POP3 proc ; is working
		push dx
		call AnalyzeAdressingByte
		cmp adrReg, 000b
		je correctPop3
			call UNRECOGNIZED1
			jmp endPop3
		correctPop3:
		mov dx, offset opNamePOP
		call PrintString
		call PrintModOpkRM
		endPop3:
		pop dx
		ret
	POP3 endp
	
	CALL1 proc ; should be working
		push dx
		mov dx, offset opNameCALL
		call PrintString
		call AdressWithSegReg
		pop dx
		ret
	CALL1 endp
	
	MOV3 proc ; is working
		push dx
		mov dx, offset opNameMOV
		call PrintString
		
		mov dh, 00h
		mov dl, rByte
		and dl, 10b
		cmp dl, 10b
		jne RegToMemMOV3
		mov dl, rByte
		and dl, 1b
		cmp dl, 1b
		je isWordDMOV3
			mov dx, offset bytePtr	
			call PrintString
			call PrintPrefixDefaultDS
			call PrintNextTwoBytes
			call PrintBracket
			call PrintSemicolonSpace	
			mov dx, offset reg000; w = 0
			call PrintString						
			pop dx
			ret
		isWordDMOV3: ; w = 1
			mov dx, offset wordPtr	
			call PrintString
			call PrintPrefixDefaultDS	
			call PrintNextTwoBytes
			call PrintBracket
			call PrintSemicolonSpace	
			mov dx, offset regW000; w = 1
			call PrintString						
			pop dx
			ret
		RegToMemMOV3:
		mov dl, rByte
		and dl, 1b
		cmp dl, 1b
		je isWordMOV3
			mov dx, offset reg000; w = 0
			call PrintString			
			call PrintSemicolonSpace	
			mov dx, offset bytePtr
			call PrintString			
			jmp MOV3Ending
		isWordMOV3: ; w = 1
			mov dx, offset regW000; w = 1
			call PrintString				
			call PrintSemicolonSpace	
			mov dx, offset wordPtr	
			call PrintString
		MOV3Ending:		
		call PrintPrefixDefaultDS	
		call PrintNextTwoBytes
		call PrintBracket
		pop dx
		ret
	MOV3 endp
	
	MOV4 proc ; is working
		push dx
		mov dx, offset opNameMOV
		call PrintString
		cmp rByte, 0B7h
		ja mov4Word
			PrintRegValueFromOP reg000
			call PrintSemicolonSpace
			call PrintNextOneByte
			jmp endMov4
		mov4Word:
			PrintRegValueFromOP regW000
			call PrintSemicolonSpace
			call PrintNextTwoBytes
		endMov4:
		pop dx
		ret
	MOV4 endp
	
	RET1 proc ; is working
		push dx
		mov dx, offset opNameRET
		call PrintString
		call PrintNextTwoBytes
		pop dx
		ret
	RET1 endp
	
	RET2 proc ; is working
		push dx
		mov dx, offset opNameRET
		call PrintString
		pop dx
		ret
	RET2 endp
	
	MOV5 proc ; is working
		push dx
		mov dx, offset opNameMOV
		call PrintString
		call AnalyzeAdressingByte
		call PrintModOpkRM
		call AddImmediateW		
		pop dx
		ret
	MOV5 endp
	
	RET3 proc ; is working
		push dx
		mov dx, offset opNameRET
		call PrintString
		call PrintNextTwoBytes
		pop dx
		ret
	RET3 endp
	
	RET4 proc ; is working
		push dx
		mov dx, offset opNameRET
		call PrintString
		pop dx
		ret
	RET4 endp
	
	INTER1 proc ; is working
		push dx
		mov dx, offset opNameINT
		call PrintString
		call PrintNextOneByte
		pop dx
		ret
	INTER1 endp
	
	SHL1 proc
		push dx
		call AnalyzeAdressingByte
		cmp adrReg, 100b
		jne notSHLreg
			mov dx, offset opNameSHL
			call PrintString
			call PrintModOpkRM
			call PrintSemicolonSpace
			
			and adrDW, 0010b
			cmp adrDW, 00h
			je notCl
				mov dx, offset reg001
				call PrintString
				jmp endSHL1
			notCl:
				mov dl, 31h
				call PrintSymbol
				jmp endSHL1			
		notSHLreg:
			call UNRECOGNIZED1
		endSHL1:
		pop dx
		ret
	SHL1 endp
	
	LOOP1 proc ; is working
		push dx
		mov dx, offset opNameLOOP
		call PrintString
		call PrintNextOneByte
		pop dx
		ret
	LOOP1 endp
	
	CALL2 proc ; is working
		push dx
		mov dx, offset opNameCALL
		call PrintString
		call PrintNextTwoBytes
		pop dx
		ret
	CALL2 endp
	
	JMP1 proc ; 1/~1/1 working
		push dx
		mov dx, offset opNameJMP
		call PrintString
		
		cmp rByte, 0E9h
		ja notJMP2
		call PrintNextTwoBytes
		jmp endJMP1	
		
		notJMP2:		
		cmp rByte, 0EAh
		ja notJMP3		
		call AdressWithSegReg		
		jmp endJMP1	
		
		notJMP3:
		call PrintNextOneByte		
		endJMP1:
		pop dx
		ret
	JMP1 endp
	
	MULDIV1 proc ; is working
		call AnalyzeAdressingByte
		cmp adrReg, 100b
		ja div1			
			mov dx, offset opNameMUL
			jmp endMulDiv1
		div1:
			mov dx, offset opNameDIV
		endMulDiv1:
		call PrintString
		call PrintModOpkRM
		ret
	MULDIV1 endp
	
	INCDEC1 proc ; is working
		call AnalyzeAdressingByte
		cmp adrReg, 000b
		ja dec2			
			mov dx, offset opNameINC
			jmp endMulDiv1
		dec2:
			mov dx, offset opNameDEC
		endIncDec1:
		call PrintString
		call PrintModOpkRM
		ret
	INCDEC1 endp
	
	FF1 proc ; is working
		call AnalyzeAdressingByte
		cmp adrReg, 000b
		ja notInc3			
			mov dx, offset opNameINC
			jmp endFF1
			notInc3:			
		cmp adrReg, 001b
		ja notDec3
			mov dx, offset opNameDEC
			jmp endFF1
			notDec3:		
		cmp adrReg, 010b
		ja notCall3
			mov dx, offset opNameCALL
			jmp endFF1
			notCall3:			
		cmp adrReg, 011b
		ja notCall4
			mov dx, offset opNameCALL
			jmp endFF1
			notCall4:	
			
		cmp adrReg, 100b
		ja notJmp4
			mov dx, offset opNameJMP
			mov jump, 01h
			jmp endFF1
			notJmp4:
			
		cmp adrReg, 101b
		ja notJmp5
			mov dx, offset opNameJmp
			mov jump, 01h
			jmp endFF1
			notJmp5:		
			
		cmp adrReg, 110b
		ja notPush3
			mov dx, offset opNamePUSH
			jmp endFF1
			notPush3:			
		endFF1:
		call PrintString
		call PrintModOpkRM
		mov jump, 00h
		ret
	FF1 endp
	
	UNRECOGNIZED1 proc
		push dx
		mov dl, rByte
		call PrintHexNumber
		call PrintSemicolonSpace
		mov dx, offset opNameUNRECOGNIZED
		call PrintString
		pop dx
		ret
	UNRECOGNIZED1 endp
	;------------------------------------------------------
	
	DetectOpk proc
		push ax
		mov al, rByte
	
		cmp al, 03h ; ADD reg + r/m
		ja notADD1
		call ADD1
		jmp detected
		notAdd1:
		
		cmp al, 05h ; ADD akumul. + bet. op.
		ja notADD2
		call ADD2
		jmp detected
		notADD2:
		
		cmp al, 1Fh
		ja notPUSH1
		and al, 11100111b  ; POP stekas -> seg. reg.
		cmp al, 00000110b
		je notPOP1
		cmp al, 00000111b
		jne notPUSH1
		call POP1
		jmp detected
		notPOP1: ; PUSH seg. reg. -> stekas
		call PUSH1
		jmp detected
		notPUSH1:
		
		unknownOpperand 28h
		
		cmp al, 2Bh ; SUB r/m ~ reg
		ja notSUB1
		call SUB1
		jmp detected
		notSUB1:
		
		cmp al, 2Dh ; SUB akum - bet. op.
		ja notSUB2
		call SUB2
		jmp detected
		notSUB2:
		
		unknownOpperand 38h
		
		cmp al, 3Bh ; CMP r/m ~ reg
		ja notCMP1
		call CMP1
		jmp detected
		notCMP1:
		
		cmp al, 3Dh ; CMP akum. - bet. op.
		ja notCMP2
		call CMP2
		jmp detected
		notCMP2:
		
		cmp al, 47h ; INC reg
		ja notINC1
		call INC1
		jmp detected
		notINC1:
		
		cmp al, 4Fh ; DEC reg
		ja notDEC1
		call DEC1
		jmp detected
		notDEC1:
		
		cmp al, 57h ; PUSH reg -> stack
		ja notPUSH2
		call PUSH2
		jmp detected
		notPUSH2:
		
		cmp al, 5Fh ; POP stekas -> reg
		ja notPOP2
		call POP2
		jmp detected
		notPOP2:
		
		unknownOpperand 70h
		
		cmp al, 7Fh ; 70-7F jump
		ja notIFJUMP1
		call IFJUMP1
		jmp detected
		notIFJUMP1:
		
		cmp al, 83h ; ADD/SUB/CMP r/m +- bet.op.
		ja notADDSUBCMP1
		call ADDSUBCMP1
		jmp detected
		notADDSUBCMP1:
		
		unknownOpperand 88h
				
		cmp al, 8Bh ; MOV reg <-> r/m
		ja notMOV1
		call MOV1
		jmp detected
		notMOV1:
		
		cmp al, 8Ch ; MOV seg. reg. <-> r/m
		je isMOV2
		cmp al, 8Eh
		je isMOV2
		cmp al, 8Fh ; POP stack -> r/m
		je isPOP3
		jmp notMOV2POP3
		isMOV2:
			call MOV2
			jmp detected
		isPOP3:
			call POP3
			jmp detected
		notMOV2POP3:
		
		unknownOpperand 9Ah
		
		cmp al, 9Ah ; CALL outside direct
		ja notCALL1
		call CALL1
		jmp detected
		notCALL1:
		
		unknownOpperand 0A0h
		
		cmp al, 0A3h ; mem <-> akum.
		ja notMOV3
		call MOV3
		jmp detected
		notMOV3:
		
		unknownOpperand 0B0h
		
		cmp al, 0BFh ; MOV bet. op. -> reg
		ja notMOV4
		call MOV4
		jmp detected
		notMOV4:
		
		unknownOpperand 0C2h
		
		cmp al, 0C2h ; RET inner with stack
		ja notRET1
		call RET1
		jmp detected
		notRET1:
		
		cmp al, 0C3h ; RET inner
		ja notRET2
		call RET2
		jmp detected
		notRET2:
		
		unknownOpperand 0C6h
		
		cmp al, 0C7h ; MOV bet. op. -> r/m
		ja notMOV5
		call MOV5
		jmp detected
		notMOV5:
		
		unknownOpperand 0CAh
		
		cmp al, 0CAh ; RET outer with stack
		ja notRET3
		call RET3
		jmp detected
		notRET3:
		
		cmp al, 0CBh ; RET outer
		ja notRET4
		call RET4
		jmp detected
		notRET4:
		
		cmp al, 0CDh ; INT
		ja notINT1
		call INTER1
		jmp detected
		notINT1:
		
		unknownOpperand 0D0h
		
		cmp al, 0D3h ; SHL
		ja notSHL1
		call SHL1
		jmp detected
		notSHL1:
		
		unknownOpperand 0E2h
		
		cmp al, 0E2h ; LOOP 
		ja notLOOP1
		call LOOP1
		jmp detected
		notLOOP1:
		
		cmp al, 0E3h ; JCXZ
		ja notJCXZ
		call IFJUMP1
		jmp detected
		notJCXZ:
		
		unknownOpperand 0E8h
		
		cmp al, 0E8h ; CALL inner direct
		ja notCALL2
		call CALL2
		jmp detected
		notCALL2:
		
		cmp al, 0EBh ; JMP
		ja notJMP1
		call JMP1
		jmp detected
		notJMP1:
		
		unknownOpperand 0F6h
		
		cmp al, 0F7h ; MUL/DIV 
		ja notMULDIV1
		call MULDIV1
		jmp detected
		notMULDIV1:
		
		unknownOpperand 0FEh
		
		cmp al, 0FEh ; INC/DEC
		ja notINCDEC1
		call INCDEC1
		jmp detected
		notINCDEC1:
		
		cmp al, 0FFh ; INC/DEC/CALL/JMP/PUSH
		ja notFF1
		call FF1
		jmp detected
		notFF1:
		
		unrecognizedOp:
			call UNRECOGNIZED1
		
		detected:
			call PrintNewLine
		pop ax
		ret	
	DetectOpk endp
	
	Start:	
		mov ax, @data
		mov ds, ax	
		
		call ReadParameters	
		call CreateOutput	
		call OpenInput
		
		mov cx, 0100h
		Skip100h:
			call ReadByte
		loop Skip100h
		
		MainLoop:
			call ReadByte
			call isPrefix
			cmp prefix, 00h
			je notPrefix
				call ReadByte
			notPrefix:
			
			call DetectOpk
			call WriteBufferToFile
		jmp MainLoop
		
	Ending:	
		mov	ah, 4Ch	
		mov	al, 0			
		int	21h	
	END Start
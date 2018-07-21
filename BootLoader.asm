org 0x7C00				;1)
jmp short Boot				;2)
nop					;3)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=		;4)
bpbOEM			db "AAAAAAAA"	;5) OEM label for the disk (8 bytes)		
bpbBytesPerSector:  	DW 512		;6) The size of the sectors in bytes
bpbSectorsPerCluster: 	DB 1		;7) How many sectors make up a cluster
bpbReservedSectors: 	DW 1		
bpbNumberOfFATs: 	DB 2		
bpbRootEntries: 	DW 224		
bpbTotalSectors: 	DW 2880		;How many sectors exist on this disk
bpbMedia: 		DB 0xf0		;The type of media
bpbSectorsPerFAT: 	DW 9		;how many sectors the FAT table takes up on disk
bpbSectorsPerTrack: 	DW 18		;how many sectors fit on one track
bpbHeadsPerCylinder: 	DW 2		;how many physical heads 
bpbHiddenSectors: 	DD 0
bpbTotalSectorsBig: 	DD 0
bsDriveNumber: 		DB 0
bsUnused: 		DB 0
bsExtBootSignature: 	DB 0x29
bsSerialNumber:		DD 0xa0a1a2a3
bsVolumeLabel: 		DB "AAAAAAAAAAA"
bsFileSystem: 		DB "FAT12   "
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
Boot:
	cli
	mov ax, 0x0000
	mov es, ax
	mov ds, ax
	mov ss, ax
	mov cs, ax
	mov sp, 0x7C00
	mov bp, 0x0500
	sti
	call ResetDisk
	call LoadFAT
	cli
	hlt
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
BPrint:
	mov ah, 0x0E
	_Loop:
	lodsb
	cmp al, 0
	je _Done
	int 0x10
	jmp _Loop
	_Done:
	ret

WriteHex:
	mov ah, 0x0E
	lea bx, [HEX] 
	mov ch, al
	shr al, 4					;AL now equals the Upper nibble
	and al, 0x0F							
	xlat						
	int 0x10
	shl ch, 4
	shr ch, 4
	mov al, ch
	and al, 0x0F
	xlat
	int 0x10
	ret
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
ResetDisk:
	pusha
	mov ah, 0x00
	mov dl, 0x00
	int 0x13
	jc DiskError
	popa
	ret

ReadDisk:
	pusha
	mov si, READING
	call BPrint
	popa
	mov ah, 0x02
	int 0x13
	jc DiskError
	ret


DiskError:
	pusha
	mov si, DISKERR
	call BPrint
	popa
	mov al, 0x00
	mov al, ah
	call WriteHex
	cli
	hlt
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
LoadFAT:
	mov al, 0x09
	mov ch, 0
	mov cl, 1
	mov dx, 0x0000
	mov bx, 0x7E00
	call ReadDisk
	ret

FindRootDir:
	mov ax, word [bpbSectorsPerFAT]
	mov bx, 0x0002
	mul bx
	add ax, 1					
	call LBAToCHS					
	mov al, 14
	call ReadDisk					
	mov cx, 0x0008
	ret
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
LBAToCHS:
	xor dx, dx			; Upper 16-bit of 32-bit value set to 0 for DIV
	div word [bpbSectorsPerTrack]	; 32-bit by 16-bit DIV : LBA / SPT
	mov cl, dl			; CL = S = LBA mod SPT
	inc cl				; CL = S = (LBA mod SPT) + 1
	xor dx, dx			; Upper 16-bit of 32-bit value set to 0 for DIV
	div word [bpbHeadsPerCylinder]	; 32-bit by 16-bit DIV : (LBA / SPT) / HEADS
	mov dh, dl			; DH = H = (LBA / SPT) mod HEADS
   	mov dl, [bsDriveNumber]		; boot drive
   	mov ch, al			; CH = C(lower 8 bits) = (LBA / SPT) / HEADS
   	shl ah, 6			; Store upper 2 bits of 10-bit Cylinder into
    	or cl, ah			;upper 2 bits of Sector (CL)
	ret
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
READING db 'Reading Disk...',0x0A,0x0D,0
DISKERR db '!!ATTENTION!! - Disk Error. INT:0x13 - AH:0x',0
HEX db '0123456789ABCDEF'
times 510 - ($-$$) db 0
dw 0xAA55
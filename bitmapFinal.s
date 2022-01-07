.data

printChar:              .asciz "%c"
leadTail:               .asciz "CCCCCCCCSSSSEE1111444400000000"
messageToEncrypt:       .asciz  "bike bike bike bike"
cleanFile:              .asciz "barcodeClear.bmp"
encryptedFile:          .asciz "barcodeEnc.bmp"
transferRLE:            .space 3456
decryptedMessage:       .space 3072
fileHeader:             .space 14
bitmap_Header:          .space 40
pixelData:              .space 3456
lengths:                .equ    length, 3510
messageLeadTail:        .space 3456

.text
.global barcodes
.global bitmapFileHeader
.global bitmapHeader


.global main
main:

#Prologue
pushq %rbp
movq %rsp, %rbp


    # CREATE A BITMAP

    subq    $32, %rsp                       # 1. for read amount of data; 2. decrypt read file amount of data; 3. data of first file; 4. data of second file

    movq    $pixelData, %rdi               # rdi is used for the indexing of the pixel bytes
    call    barcodes
    
    movq    $fileHeader, %rdi              # use the same rdi to keep track of the index (bytes) in bitmap
    call    bitmapFileHeader

    movq    $bitmap_Header, %rdi
    call    bitmapHeader

    movq    $cleanFile, %rdi           # rdi - name of file, rsi - register used to write to file, rdx - number of bytes that need to be written
    movq    $fileHeader, %rsi
    movq    $length, %rdx
    call    write_file





    # ENCRYPTION
    # Takes in a message string and creates a file with a bitmap that has that message encrypted in it.


    # Read from the specified file          # Each time we return value in rax for each subroutine
    movq    $cleanFile, %rdi
    leaq    -8(%rbp), %rsi
    call    read_file                       
    movq    %rax, -16(%rbp)                 # save the first memory location of the file in the memory; start of list of characters, first data of file

                                            # Putting lead/tail to the message
    movq    $messageToEncrypt, %rdi
    movb    (%rdi), %r8b
    movq    $messageLeadTail, %rsi
    call    encrypt
                                            # Compressing the message
    movq    $messageLeadTail, %rdi
    movq    %rax, %rsi                      
    movq    $transferRLE, %rdx
    call    RLEencoder

                                            # XORing the message
    
    movq    -16(%rbp), %rdx                 # use the file in memory to xor it with the message
    addq    $54, %rdx                       # constant index of the first byte of the pixel data in bitmap
    movq    $transferRLE, %rdi
    movq    %rax, %rsi
    movq    %rdx, %rcx
    call    XOROP

    movq    -16(%rbp), %rax

                                            # Putting the final result in file
    movq    $encryptedFile, %rdi
    movq    %rax, %rsi                      # store contents of image in a file named "bitmapEnc.bmp" in this case
    movq    $length, %rdx                   # length of "bitmapEnc.bmp"
    call    write_file  

                                          # Free the buffer used by read_file. (gotten from brainfuck, for allocated memory; we will run out of space otherwise)
    movq    -16(%rbp), %rdi
    call    free                          # C function takes file descriptor






    # DECRYPTION
    # Takes file name containing a bitmap and prints out the decrypted message. 


    
    movq    $encryptedFile, %rdi                        # Reading from the encoded bitmap
    leaq    -8(%rbp), %rsi
    call    read_file
    movq    %rax, -24(%rbp)

                                                        # Reading from the clean bitmap
    movq    $cleanFile, %rdi
    leaq    -16(%rbp), %rsi
    call    read_file
    movq    %rax, -32(%rbp)

                                                        # Getting the pixel data from the enc bitmap
    movq    -24(%rbp), %rdi
    movq    $pixelData, %rsi
    call    bitmapToEncBarcode

                                                        # XORing the files and extracting the message to transferRLE
    movq    -32(%rbp), %rdi
    addq    $54, %rdi
    movq    $pixelData, %rsi
    movq    $decryptedMessage, %rdx
    movq    $transferRLE, %rcx
    call    encBarcodeToRLE 
    
                                                        # Decmopressing the message and putting it into messageLeadTail
    movq    $messageLeadTail, %rdi
    movq    $transferRLE, %rsi
    movq    %rax, %rdx
    call    RLEdecoder

                                                        # Removing lead/tail and printing it
    movq    $messageLeadTail, %rdi
    movq    %rax, %rsi
    call    printDecrypted

    #epilogue
    movq    $0, %rax
    movq    %rbp, %rsp
    popq    %rbp
    ret






# INPUT/OUTPUT FUNCTIONS


# READ FUNCTION (gotten from brainfuck)

.global read_file
.global write_file

# Taken from <stdio.h>
.equ SEEK_SET,  0
.equ SEEK_CUR,  1
.equ SEEK_END,  2
.equ EOF,      -1

file_mode_read:  .asciz "r"
file_mode_write: .asciz "w"

# char * read_file(char const * filename, int * read_bytes)
#
# Read the contents of a file into a newly allocated memory buffer.
# The address of the allocated memory buffer is returned and
# read_bytes is set to the number of bytes read.
#
# A null byte is appended after the file contents, but you are
# encouraged to use read_bytes instead of treating the file contents
# as a null terminated string.
#
# Technically, you should call free() on the returned pointer once
# you are done with the buffer, but you are forgiven if you do not.
read_file:
    pushq %rbp
    movq %rsp, %rbp

    # internal stack usage:
    #  -8(%rbp) saved read_bytes pointer
    # -16(%rbp) FILE pointer
    # -24(%rbp) file size
    # -32(%rbp) address of allocated buffer
    subq $32, %rsp

    # Save the read_bytes pointer.
    movq %rsi, -8(%rbp)

    # Open file for reading.
    movq $file_mode_read, %rsi
    call fopen
    testq %rax, %rax
    jz _read_file_open_failed
    movq %rax, -16(%rbp)

    # Seek to end of file.
    movq %rax, %rdi
    movq $0, %rsi
    movq $SEEK_END, %rdx
    call fseek
    testq %rax, %rax
    jnz _read_file_seek_failed

    # Get current position in file (length of file).
    movq -16(%rbp), %rdi
    call ftell
    cmpq $EOF, %rax
    je _read_file_tell_failed
    movq %rax, -24(%rbp)

    # Seek back to start.
    movq -16(%rbp), %rdi
    movq $0, %rsi
    movq $SEEK_SET, %rdx
    call fseek
    testq %rax, %rax
    jnz _read_file_seek_failed

    # Allocate memory and store pointer.
    # Allocate file_size + 1 for a trailing null byte.
    movq -24(%rbp), %rdi
    incq %rdi
    call malloc
    test %rax, %rax
    jz _read_file_malloc_failed
    movq %rax, -32(%rbp)

    # Read file contents.
    movq %rax, %rdi
    movq $1, %rsi
    movq -24(%rbp), %rdx
    movq -16(%rbp), %rcx
    call fread
    movq -8(%rbp), %rdi
    movq %rax, (%rdi)

    # Add a trailing null byte, just in case.
    movq -32(%rbp), %rdi
    movb $0, (%rdi, %rax)

    # Close file descriptor
    movq -16(%rbp), %rdi
    call fclose

    # Return address of allocated buffer.
    movq -32(%rbp), %rax
    movq %rbp, %rsp
    popq %rbp
    ret

_read_file_malloc_failed:
_read_file_tell_failed:
_read_file_seek_failed:
    # Close file descriptor
    movq -16(%rbp), %rdi
    call fclose

_read_file_open_failed:
    # Set read_bytes to 0 and return null pointer.
    movq -8(%rbp), %rax
    movq $0, (%rax)
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret


# WRITE FUNCTION
# rdi - name of file, rsi - register used to write to file, rdx - number of bytes that need to be written

write_file:
    pushq %rbp
    movq %rsp, %rbp

    subq $24, %rsp

    # Save the read_bytes (from reading function).
    movq %rdx, -8(%rbp)
    movq %rsi, -24(%rbp)

    # Get file for reading.
    movq $file_mode_write, %rsi
    call fopen                          # takes file name and the mode
    movq %rax, -16(%rbp)                # file descriptor

    # Writing to the file.
    movq    -24(%rbp), %rdi
    movq    $1, %rsi                    # OS setting that reads file "1"
    movq    -8(%rbp), %rdx
    movq    -16(%rbp), %rcx
    call    fwrite                      # takes in buffer, file descriptor, and size

    # Closing file descriptor
    movq    -16(%rbp), %rdi
    call    fclose

    movq %rbp, %rsp
    popq %rbp
    ret




# Creates a clean barcode

barcodes:

#Prologue
pushq %rbp
movq %rsp, %rbp

movq $0, %rax           # barcodeValue displacement
movq $32,%rdx           # number of lines upperBound
#movq $barValue, %rdi    # storing the address of barValue


lines:                  # expressing an individual line

call white
call white
call white
call white
call white
call white
call white
call white

call black
call black
call black
call black
call black
call black
call black
call black

call white
call white
call white
call white

call black
call black
call black
call black

call white
call white

call black
call black
call black

call white
call white

call red

decq %rdx

cmpq $0, %rdx
jne lines


jmp endBar                     # finishing the function


white:

#Prologue
pushq %rbp
movq %rsp, %rbp

movb $255, (%rdi, %rax, 1)
incq %rax
movb $255, (%rdi, %rax, 1)
incq %rax
movb $255, (%rdi, %rax, 1)
incq %rax

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   

black:

#Prologue
pushq %rbp
movq %rsp, %rbp

movb $0, (%rdi,%rax,1)
incq %rax
movb $0, (%rdi,%rax,1)
incq %rax
movb $0, (%rdi,%rax,1)
incq %rax

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   
red:

#Prologue
pushq %rbp
movq %rsp, %rbp

movb $0, (%rdi,%rax,1)
incq %rax
movb $0, (%rdi,%rax,1)
incq %rax
movb $255, (%rdi,%rax,1)
incq %rax

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   
   
endBar:  

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   
   


# Inputs the Bitmap File Header in the first bytes in bitmap 

bitmapFileHeader:

#Prologue
pushq %rbp
movq %rsp, %rbp

movq $0, %rax               # setting the initial displacement


# Signature
movb $0x42, %cl             # setting signature "B"
movb %cl, (%rdi, %rax, 1)
incq %rax

movb $0x4d, %cl             # setting signature "M"
movb %cl, (%rdi, %rax, 1)
incq %rax


# File size

movl $3510, (%rdi, %rax, 1)
addq $4, %rax


# Reserved field

movl $0x00000000, (%rdi, %rax, 1)
addq $4, %rax


# Offset of pixel data

movl $54, (%rdi, %rax, 1)            # 4 byte address?????
addq $4, %rax


#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret



# Puts Bitmap Header in the next bytes of the bitmap

bitmapHeader:

#Prologue
pushq %rbp
movq %rsp, %rbp

movq  $0, %rax   # setting the initial displacement gotten from fileheader


# Header size
movl $40, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax


# Width size
movl $32, %ecx            
movl %ecx , (%rdi, %rax, 1)
addq $4, %rax


# Height size
movl $32, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax


# Reserved size
movw $1, %cx            
movw %cx, (%rdi, %rax, 1)
addq $2, %rax

# bits per pixel
movw $24, %cx            
movw %cx, (%rdi, %rax, 1)
addq $2, %rax

# Compression method
movl $0, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax

# Pixel data size
movl $3456, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax

# Horizontal resolution
movl $2835, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax

# Vertical resolution
movl $2835, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax

# Color palette
movl $0, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax

# Number of important colors
movl $0, %ecx            
movl %ecx, (%rdi, %rax, 1)
addq $4, %rax

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret




.global encrypt
.global RLEencoder
.global XOROP
.global pixelDataRoutine

# Appends lead and tail to the given message in "messageToEncrypt"

encrypt:

#Prologue
pushq %rbp
movq %rsp, %rbp

pushq   %rdi

movq %rsi, %r8              # loading lead/tail address
movq $leadTail, %rdi        # loading lead/tail address

movq $0, %rax               # setting initial displacement
movq $0, %rcx               # setting transfer displacement
movq    $0, %rdx

lead:                      

movb (%rdi, %rax, 1), %dl       # storing the character
movb %dl, (%r8,%rcx,1)          # transfering the character

incq %rax                       # incrementing the counter registers
incq %rcx  
cmpb $0,%dl                     # checking for null character
jne lead

decq %rcx                       # remove one from displ, because these loops add the zero byte as well

popq    %rdi                    # preparing reg for new iterations
movq $0, %rax


internalPart:

movb (%rdi, %rax, 1), %dl       # storing the character
movb %dl, (%r8,%rcx,1)          # transfering the character


incq %rax                       # incrementing the counter registers
incq %rcx  
cmpb $0,%dl                     # checking for null character
jne internalPart


decq %rcx                       # remove one from displ, because these loops add the zero byte as well

movq $leadTail, %rdi            # preparing reg for new iterations
movq $0, %rax


tail:

movb (%rdi, %rax, 1), %dl       # storing the character
movb %dl, (%r8,%rcx,1)          # transfering the character

incq %rax                       # incrementing the counter registers
incq %rcx  
cmpb $0,%dl                     # checking for null character
jne tail

decq %rcx                       # remove one from displ, because these loops add the zero byte as well

movb (%r8,%rcx,1), %r8b


movq %rcx, %rax                 # storing the length of message

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   



# RLE encodes the message that now also has lead and tail
   
RLEencoder:

    #Prologue
    pushq %rbp
    movq %rsp, %rbp

    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    movq    %rdx, %r12                  # setting up the address for enc
    movq    %rdi, %rdx                  # setting up the address
    movq    %rsi, %rcx                  # transfer counter signifies the end of the transfer message
    movq    $0, %rax                    # initial displacement transfer
    movq    $0, %r11                    # transferRLE counter
    movq    $1, %r13                    # transfer parent counter

    movq    $0, %r8
    movq    $0, %r10
    movq    $1,%r9                     # counting the current character

    movb (%rdx, %rax, 1), %r8b      # taking prev char
    incq %rax


loopEnc:

    cmpq %rcx,%r13
    je end

    movb (%rdx, %rax, 1), %r10b      # taking next char

    cmpb %r8b, %r10b
    je equals

notEquals:

    incq %rax                        # in order to access next char

    movb %r9b, (%r12,%r11,1)         # storing the amount of chars
    incq %r11
    movb %r8b, (%r12,%r11,1)         # storing the char itself
    incq %r11              

    movq $1, %r9                     # clearing the amount of chars
    movq %r10, %r8

    incq %r13
    jmp loopEnc

equals:

    incq %rax                        # in order to access next char
    movq %r10, %r8                   # preparing the check char for next iteration
    incq %r9

    incq %r13
    jmp loopEnc

end:

    movb %r9b, (%r12,%r11,1)         # storing the last group of character before finishing
    incq %r11
    movb %r8b, (%r12,%r11,1)        
    incq %r11

    movq %r11, %rax                  # storing the length of the compressed message


    popq %r15
    popq %r14
    popq %r13
    popq %r12


    #epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   



# Takes the RLE encoded message and XORes it with a barcode to create an encrypted barcode

XOROP:

    #Prologue
    pushq %rbp
    movq %rsp, %rbp

    pushq   %rsi    

    movq $0, %rax                    # setting up the initial displacement
    movq %rcx, %r8                   # encrypted barcode first address


copyNewBarValue:

    movb (%rdx,%rax,1), %r9b         # getting a byte from clean barcode
    movb %r9b,(%r8,%rax,1)           # setting the same value in enc barcode
    incq %rax

    cmpq $3456, %rax
    jne copyNewBarValue


    movq $0, %rax                    # resetting so we can xor the message and barcode


modify:

    movb (%rdi,%rax,1), %r9b         # getting one byte from message
    movb (%r8,%rax,1), %r10b         # getting one byte from enc barcode

    xorb %r9b, %r10b                 # storing the encrypted bytes in r10b

    movb %r10b, (%r8,%rax,1)         # storing the value in enc barcode

    incq %rax


    cmpq -8(%rbp), %rax
    jne modify


#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret


.global RLEdecoder
.global encBarcodeToRLE
.global bitmapToEncBarcode
.global printDecrypted


# Remove the RLE encoding and just gives us the message with a lead and tail

RLEdecoder:
 
#Prologue
pushq %rbp
movq %rsp, %rbp

movq $0,%r9                         # counter for transfer
 
movq $0, %rax
 
 
trDecodeLoop:
 
movb (%rsi,%rax,1), %cl             # putting the amount of the char in cl
incq %rax                           # incrementing the value of rax
movb (%rsi,%rax,1), %r8b            # putting the char in r8b


    fillTransfer:
   
    movb %r8b, (%rdi,%r9,1)         # putting a character in transfer
    movb (%rdi,%r9,1), %r10b
    incq %r9
    decb %cl
   
    cmpb $0, %cl
    jne fillTransfer
   

incq %rax
cmpq %rdx, %rax
jl trDecodeLoop
   

movq %r9, %rax                      # storing the length of message
 
#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   
   

# Extracts the RLE encoded message from the pixel data using a key (clean barcode)
   
encBarcodeToRLE:

#Prologue
pushq %rbp
movq %rsp, %rbp


movq %rsi, %rax                 # putting the enc barcode in rax
movq %rcx, %r9                  # putting the address of the transferRLE
movq %rdx, %r8                  # init new variable to store boxed rle
movq $0, %rdx                   # counter init


decEncBarcode:

movb (%rax,%rdx,1), %sil         # storing enc byte in sil
movb (%rdi,%rdx,1), %cl          # storing key byte in cl


xorb %cl,%sil                    # storing decode byte in sil

movb %sil,(%r8,%rdx,1)           # storing the dec byte

incq %rdx                        # incrementing counter

cmpq $3072, %rdx
jne decEncBarcode


movq $0, %rdx                    # clearing the counter

extractLead:

movb (%r8,%rdx,1), %r10b         # storing byte
movb %r10b, (%r9,%rdx,1)         # storing byte in transfer rle
incq %rdx

cmpq $12,%rdx                    # lead and tail are 2x6 bytes long = 12 
jne extractLead


movw $0x4308, %ax                # signal register (08, 43 (=C) in succession)
movq $0, %rsi

extractMessageTail:

movb (%r8,%rdx,1), %r10b         # storing byte
movb %r10b, (%r9,%rdx,1)         # storing byte in transfer rle


    checkForMatch:
    movw (%r8,%rdx,1), %cx
    cmpw %cx, %ax
    je endExtraction
   
   
incq %rdx
incq %rsi

jmp extractMessageTail
 

endExtraction:

movq $0, %rax

extractRest:

movb (%r8,%rdx,1), %r10b         # storing byte
movb %r10b, (%r9,%rdx,1)         # storing byte in transfer rle
incq %rdx
incq %rax

cmpq $11, %rax
jne extractRest


movq %rdx, %rax

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
   
   


# Takes the pixel data from the bitmap and stores it in a variable we then use to get the message (with XORing).

bitmapToEncBarcode:

#Prologue
pushq %rbp
movq %rsp, %rbp

movq %rsi, %rax                 # putting the enc barcode in rax
movq %rdi, %r9                  # putting the address of the bitmap
movq $54, %rdx                  # setting up the initial displacement
movq $0, %rsi                   # storing the enc barcode displacement


pixelDataExtraction:

movb (%r9,%rdx,1), %dil         # getting a byte from pixel data
movb %dil, (%rax,%rsi,1)        # storing the byte in enc barcode

incq %rdx
incq %rsi

cmpq $3072, %rsi
jne pixelDataExtraction


movq $0, %rsi
movb (%rax,%rsi,1), %r14b

movq $1, %rsi
movb (%rax,%rsi,1), %r14b


#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret




# rdi - message, rsi - length

printDecrypted:
 
#Prologue
pushq %rbp
movq %rsp, %rbp

movq %rsi, %rdx                 # transferring the counter to rdx
movq $30,%rcx                   # storing a initial displacement
subq $30,%rdx                   # storing a upperBound


printLoop:

pushq %rdi
pushq %rdx
pushq %rcx
pushq %r8

movb (%rdi,%rcx,1), %sil        # storing the character to print

movq $0, %rax                   # no vector arguments needed
movq $printChar, %rdi           # putting prompt number instruction as first argument
call printf

popq %r8
popq %rcx
popq %rdx
popq %rdi

incq %rcx                       # incrementing print counter


cmpq %rdx, %rcx
jl printLoop
 

#epilogue
    movq %rbp, %rsp
    popq %rbp
    ret


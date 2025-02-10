;-------------------------------------------------------------------------------
; Include files
            .cdecls C,LIST,"msp430.h"  ; Include device header file
;-------------------------------------------------------------------------------

            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.

            .global __STACK_END
            .sect   .stack                  ; Make stack linker segment ?known?

            .text                           ; Assemble to Flash memory
            .retain                         ; Ensure current section gets linked
            .retainrefs

RESET       mov.w   #__STACK_END,SP         ; Initialize stack pointer




init:
            ; stop watchdog timer
            mov.w   #WDTPW+WDTHOLD,&WDTCTL

            ; Disable low-power mode
            bic.w   #LOCKLPM5,&PM5CTL0
            bis.b   #BIT0, &P2REN

            ; SDA ---------------------------------------------
            bic.b   #BIT0, &P2OUT           ; Clear P2.0 Output
            bis.b   #BIT0, &P2DIR           ; Set P2.0 Direction

            ; SCL ---------------------------------------------
            bic.b   #BIT1, &P2OUT           ; Clear P2.1 Output
            bis.b   #BIT1, &P2DIR           ; Set P2.1 Direction
            

main:
            mov.w #0, R14
            mov.w #0, R9
            mov.w  #00000001b, R12              ; tx_byte
            call #i2c_start
            call #i2c_tx_byte
            call #i2c_rx_ack
            nop
            nop
            call #frame_to_frame
            bic.b   #BIT0, &P2DIR           ; set P2.0 as an input
            call #i2c_rx_byte
            call #i2c_rx_byte
            call #i2c_rx_byte
            call #i2c_rx_byte
            call #i2c_rx_byte
            call #i2c_rx_byte
            call #i2c_rx_byte
            call #i2c_stop
            jmp main

            ; 1 for READ 
            ; 0 for WRITE
;------------------------------------------------------------------------------
;           START OF SCL DELAY LOOP
;------------------------------------------------------------------------------

one_sec:                                ; clock is 250kHz
            mov.w   #0, R15             ; put 0 in R15
            call #inner                 ; call nested loop
            inc.w   R14                 ; add 1 to R14
            cmp.w   #5, R14             ; compare R14 to 5
            jnz     one_sec             ; if R14 is 5 continue (total count time = 1s), else repeat subroutine
            xor.b   #BIT1, &P2OUT       ; Toggle SCL
            mov.w   #0, R14             ; reset 5 counter
            ret                         ; return to main

inner:                                  ; count up to 42000
            inc.w   R15                 ; add 1 to R15
            cmp.w   #17, R15            ; compare R15 to 42000
            jnz     inner               ; if R15 is 42000 continue, else repeat subroutine
            ret                         ; return to one_sec
;------------------------------------------------------------------------------
;           END OF SCL DELAY LOOP
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
;          START OF INIT, START, STOP
;------------------------------------------------------------------------------
i2c_init:
            bis.b   #BIT0, &P2OUT           ; Set SDA HIGH
            bis.b   #BIT1, &P2OUT           ; Set SCL HIGH
            ret                             ; return to main

i2c_start:

            bic.b   #BIT0, &P2OUT           ; Pull SDA LOW
            nop
            bic.b   #BIT1, &P2OUT           ; Pull SCL LOW
            nop
            nop
            ret                             ; return to main
i2c_stop:
            bis.b   #BIT1, &P2OUT           ; Pull SCL HIGH
            nop                             ; delay
            bis.b   #BIT0, &P2OUT           ; Pull SDA HIGH
            nop
            nop
            ret                             ; return to main
;------------------------------------------------------------------------------
;          END OF INIT, START, STOP
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
;          START OF TRANSMIT
;------------------------------------------------------------------------------
i2c_tx_byte: 
        bit.b #10000000b, R12       ; test BIT 7 of tx_byte
        jnz tx1                     ; if 0, transmit 0 to target device (tx0 subroutine) FALSE
        jz tx0                      ; if 1, transmit 1 to target device (tx1 subroutine)


tx0:    
        bic.b   #BIT0, &P2OUT           ; Pull SDA LOW
        nop                             ; Delay for 6.6 us
        bis.b   #BIT1, &P2OUT           ; Pull SCL HIGH
        nop                             ; Delay for 6.6 us
        bic.b   #BIT1, &P2OUT           ; Pull SCL LOW
        nop                             ; Delay for 6.6 us
        bic.b   #BIT0, &P2OUT           ; Pull SDA LOW
        rlc.b   R12                     ; rotate address bits
        inc     R9                      ; increment address bit counter
        cmp.w #8, R9                    ; have we compared every bit in address?
        jnz  i2c_tx_byte                ; if not, continue parsing
        jmp DONE                        ; if done, go to DONE


tx1:
        
        bis.b   #BIT0, &P2OUT           ; Pull SDA HIGH
        nop                             ; Delay for 6.6 us
        bis.b   #BIT1, &P2OUT           ; Pull SCL HIGH
        nop                             ; Delay for 6.6 us
        bic.b   #BIT1, &P2OUT           ; Pull SCL LOW
        nop                             ; Delay for 6.6 us
        bic.b   #BIT0, &P2OUT           ; Pull SDA LOW
        rlc.b   R12                     ; rotate address bits
        inc     R9                      ; increment address bit counter
        cmp.w #8, R9                    ; have we compared every bit in address?
        jnz  i2c_tx_byte                ; if not, continue parsing
        jmp DONE                        ; if done, go to DONE


DONE:
        ret


;i2c_tx_ack:
        ; after sending a byte, target will send an ACK or NACK by holding 
        ; SDA low during next SCL cycle. Master must release conrol of SDA
        ; and set SDA as an input. Read section 3.1.6 in I2C manual
        ;bic.b   #BIT0, &P2OUT           ; Pull SDA LOW
        nop                             ; Delay for 6.6 us
        bis.b   #BIT1, &P2OUT           ; Pull SCL HIGH
        nop                             ; Delay for 6.6 us
        bic.b   #BIT1, &P2OUT           ; Pull SCL LOW
        nop                             ; Delay for 6.6 us
        ;bic.b   #BIT0, &P2OUT           ; Pull SDA LOW
        ret

i2c_rx_ack:
        bic.b   #BIT0, &P2DIR             ; set P2.0 as an input
        bis.b   #BIT0, &P2REN             ; enable resistors on P2.0
        bis.b   #BIT0, &P2OUT             ; enable pull up resistor on P2.0
        bis.b   #BIT1, &P2OUT             ; Pull SCL HIGH
        nop
        nop
        bic.b   #BIT1, &P2OUT             ; Pull SCL LOW
        nop
        ret

frame_to_frame:
        bic.b  #BIT1, &P2OUT            ; set SCL LOW
        bis.b  #BIT0, &P2OUT            ; set SDA HIGH
        nop
        nop
        bic.b  #BIT0, &P2OUT            ; set SDA LOW
        nop
        nop
        ret

i2c_rx_byte:
        nop                             ; Delay for 6.6 us
        bis.b   #BIT1, &P2OUT           ; Pull SCL HIGH
        nop                             ; Delay for 6.6 us
        bic.b   #BIT1, &P2OUT           ; Pull SCL LOW
        nop                             ; Delay for 6.6 us
        ret

        




;------------------------------------------------------------------------------
;          END OF TRANSMIT
;------------------------------------------------------------------------------
        

;------------------------------------------------------------------------------
;           Interrupt Service Routines
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR            ; MSP430 RESET Vector
            .short  RESET                   ;

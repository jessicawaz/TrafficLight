;
; FinalTest.asm
;
; Created: 12/7/2020 12:42:13 PM
; Author : Jessica Wazbinski
; Traffic light simulator program


.equ green_on = 6
.equ yellow_on = 2
.equ red_on = 4

; configure interrupt vector table
.org 0x0000                                       ; reset
          rjmp      main

.org INT0addr                                     ; External interrupt request 0
          rjmp      ext0_isr  

.org OC1Aaddr                                     ; Timer1 ctc mode interrupt A
          rjmp      oc1a_isr

.org INT_VECTORS_SIZE                             ; end of vector table

main:
          ; initialize stack pointer
          ldi       r16,HIGH(RAMEND)
          out       SPH,r16
          ldi       r16,LOW(RAMEND)
          out       SPL,r16

          ; initialize I/O ports
          cbi       DDRD,DDD2                     ; set button(pedestrian) for input
          sbi       PORTD,PD2                     ; set button(pedestrian) for pull-up

          sbi       DDRB,DDB3                     ; LED4 output for crosswalk light
          sbi       DDRB,DDB2                     ; LED3 output for red light
          sbi       DDRB,DDB1                     ; LED2 output for yellow light
          sbi       DDRB,DDB0                     ; LED1 output for green light

          sbi       PORTB,PB0                     ; sets green on initially
          cbi       PORTB,PB3                     ; sets crosswalk false initially

          ; toggle masks for LED states
          ldi       r17,(1<<PB3)                  ; toggle for LED4 (white)
          ldi       r18,(1<<PB2)                  ; toggle for LED3 (red)
          ldi       r19,(1<<PB1)                  ; toggle for LED2 (yellow)
          ldi       r22,(1<<PB0)                  ; toggle for LED1 (green)

          ; configure interrupt for button
          ldi       r21,(1<<INT0)                 ; enable interrupt 0
          out       EIMSK,r20

          ; configure interrupt sense control
          ldi       r21,(1<<ISC01)                ; set falling edge
          sts       EICRA,r20                     ; interrupt sense control bits
          
          ; timer1 for 1s delay: 

          clr       r16                           ; counter = 0

          ; 1) set counter to 0
          clr       r20
          sts       TCNT1H,r20
          sts       TCNT1L,r20

          ; 1.1) set 1s delay in output compare register
          ldi       r20,HIGH(15624)               ; 1s / (1/(16MHZ/1024)) = 15625 - 1
          sts       OCR1AH,r20                    ; load high byte
          ldi       r20,LOW(15624)
          sts       OCR1AL,r20                    ; load low byte

          ; 2) set mode in timer counter control reg A
          clr       r20
          sts       TCCR1A,r20                    ; ctc mode (0<<WGM11)|(0<<WGM10)

          ; 3) set mode and clock select in timer counter control reg B
          ldi       r20,(1<<WGM12)|(1<<CS12)|(1<<CS10)
          sts       TCCR1B,r20                    ; ctc mode & 1024 prescaler

          ; 4) set ctc A interrupt in timer interrupt mask reg
          ldi       r20,(1<<OCIE1A)
          sts       TIMSK1,r20

          ; enable global interrupts
          sei

          ; endless loop
end_main: rjmp      end_main

;-------------------------------------------------
ext0_isr:
; interrupt service routine for external
; interrupt 0 (PD2) when external button
; pushed
;-------------------------------------------------
          ldi       r23,1                         ; use r23 as a t/f for crosswalk
                                                  ; set to true with button press
          reti                                    ; end ext0_isr

;-------------------------------------------------
oc1a_isr:
; interrupt service routine for timer 1
; using ctc mode for compare match A
;-------------------------------------------------
          inc       r16                           ; increment counter for light timings

          sbic      PORTB,PB0                     ; if (green = off)
          rjmp      green                         ;     jump to green 

          sbic      PORTB,PB1                     ; if (yellow = off)
          rjmp      yellow                        ;     jump to yellow

          rjmp      red                           ; jump to red after going through green & yellow loops
                                                  ; (like a default)

green:                                            
          cpi       r16,green_on                  ; if (counter == 6)
          brne      temp                          ; break 

          cbi       PORTB,PB0                     ; green light off  
          sbi       PORTB,PB1                     ; yellow light on 
          
          clr       r16                           ; counter = 0 (reset counter) 
          rjmp      temp                          ; break

yellow:
          cpi       r16,yellow_on                 ; if (counter == 2)  
          brne      temp                          ; break

          cbi       PORTB,PB1                     ; yellow light off 
          sbi       PORTB,PB2                     ; red light on 
          
          clr       r16                           ; counter = 0
          rjmp      temp                          ; break

red:       
          cpi       r23,0                         ; if (r23 == 0)
          breq      check_red                     ; jump to check_red
cross:    
          sbi       PORTB,PB3                     ; crosswalk = true
          cpi       r16,3                         ; compare r16 to 3 to check on-time for crosswalk light
          brlo      check_red                     ; branch to check_red if crosswalk time < 3 (2s)
          cbi       PORTB,PB3                     ; crosswalk = false        
          clr       r23                           ; reset r23        
          
check_red:                     
          cpi       r16,red_on                    ; if (counter == 4)     
          brne      temp                          ; break
          
          cbi       PORTB,PB2                     ; red light off 
          sbi       PORTB,PB0                     ; green light on

          clr       r16  

temp:
          reti
.data
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000      
TIMER_ACK               = 0xffff006c 

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

PICKUP                  = 0xffff00f4

# Add any MMIO that you need here (see the Spimbot Documentation)

### Puzzle
GRIDSIZE = 8
has_puzzle:        .word 0                         
puzzle:      .half 0:2000             
heap:        .half 0:2000
#### Puzzle

rng:  # Random number generator using Xorshift technique
        li $t0, 13
        li $t1, 17
        li $t2, 5
        sll $t3, $a0, $t0
        xor $a0, $a0, $t3

        srl $t3, $a0, $t1
        xor $a0, $a0, $t3

        sll $t3, $a0, $t2
        xor $a0, $a0, $t3

        andi $t0, $a0, 0x111 # Get last 3 bits, value range 0-7
        addi $t0, $t0, 1 # value range 1-8

        li $t1, 45
        mul  $v0, $t0, $t1 # return value range 45-360
        jr $ra


puzzle_solving:
        sw $zero, has_puzzle
        la $t0, puzzle
        sw $t0, REQUEST_PUZZLE
        while_loop:     
                lw $t1, has_puzzle
                bne $zero, $t1, end_while_loop
                j while_loop
        end_while_loop:
        sub $sp, $sp, 24
        sw $t0, 0($sp)
        sw $t1, 4($sp)
        sw $t2, 8($sp)
        sw $t3, 12($sp)
        sw $t4, 16($sp)
        sw $a0, 20($sp)

        la $a0, puzzle
        la $a1, heap
        li $a2, 0
        li $a3, 0
        
        jal solve
                
        lw $t0, 0($sp)
        lw $t1, 4($sp)
        lw $t2, 8($sp)
        lw $t3, 12($sp)
        lw $t4, 16($sp)
        lw $a0, 20($sp)
        add $sp, $sp, 24
        la $t4, heap
        sw $t4, SUBMIT_SOLUTION
        jr $ra



.text
main:
# Construct interrupt mask
	    li      $t4, 0
        or      $t4, $t4, REQUEST_PUZZLE_INT_MASK # puzzle interrupt bit
        or      $t4, $t4, TIMER_INT_MASK	  # timer interrupt bit
        or      $t4, $t4, BONK_INT_MASK	  # timer interrupt bit
        or      $t4, $t4, 1                       # global enable
	    mtc0    $t4, $12

# Fill in your code here

        sub $sp, $sp, 24
        sw $t0, 0($sp)
        sw $t1, 4($sp)
        sw $t2, 8($sp)
        sw $t3, 12($sp)
        sw $t4, 16($sp)
        sw $a0, 20($sp)
        
        jal puzzle_solving
                
        lw $t0, 0($sp)
        lw $t1, 4($sp)
        lw $t2, 8($sp)
        lw $t3, 12($sp)
        lw $t4, 16($sp)
        lw $a0, 20($sp)
        add $sp, $sp, 24


        lw $t0, TIMER
        add $t0, $t0, 1000
        sw $t0, TIMER
        li $t0, 10
        sw $t0, VELOCITY

        li $t1, 90
        sw $t1, ANGLE
        li $t1, 1
        sw $t1, ANGLE_CONTROL
infinite:
        j       infinite              # Don't remove this! If this is removed, then your code will not be graded!!!

.kdata
chunkIH:    .space 8  #TODO: Decrease this
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at              # Save $at
.set at
        la      $k0, chunkIH
        sw      $a0, 0($k0)             # Get some free registers
        sw      $v0, 4($k0)             # by storing them to a global variable

        mfc0    $k0, $13                # Get Cause register
        srl     $a0, $k0, 2
        and     $a0, $a0, 0xf           # ExcCode field
        bne     $a0, 0, non_intrpt

interrupt_dispatch:                     # Interrupt:
        mfc0    $k0, $13                # Get Cause register, again
        beq     $k0, 0, done            # handled all outstanding interrupts

        and     $a0, $k0, BONK_INT_MASK # is there a bonk interrupt?
        bne     $a0, 0, bonk_interrupt

        and     $a0, $k0, TIMER_INT_MASK # is there a timer interrupt?
        bne     $a0, 0, timer_interrupt

        and 	$a0, $k0, REQUEST_PUZZLE_INT_MASK
        bne 	$a0, 0, request_puzzle_interrupt

        li      $v0, PRINT_STRING       # Unhandled interrupt types
        la      $a0, unhandled_str
        syscall
        j       done

bonk_interrupt:
        sw      $0, BONK_ACK
# Fill in your code here
        li $t1, 10
        sw $t1, VELOCITY

        sub $sp, $sp, 24
        sw $ra, 0($sp)
        sw $a0, 4($sp)
        sw $t0, 8($sp)
        sw $t1, 12($sp)
        sw $t2, 16($sp)
        sw $t3, 20($sp)

        lw $a0, ANGLE
        addi $a0, $a0, 1 # Initial input value to RNG cannot be zero
        jal rng

        lw $ra, 0($sp)
        lw $a0, 4($sp)
        lw $t0, 8($sp)
        lw $t1, 12($sp)
        lw $t2, 16($sp)
        lw $t3, 20($sp)
        add $sp, $sp, 24
        li $t1, 0
        sw $t1, ANGLE_CONTROL
        sw $v0, ANGLE



        j       interrupt_dispatch      # see if other interrupts are waiting

request_puzzle_interrupt:
        sw      $0, REQUEST_PUZZLE_ACK
# Fill in your code here
        li $t0, 1       
        sw $t0, has_puzzle
        j	interrupt_dispatch

timer_interrupt:
        sw      $0, TIMER_ACK
# Fill in your code here
        li $t0, 1
        sw $t0, PICKUP

        lw $t0, TIMER
        add $t0, $t0, 1000
        sw $t0, TIMER

        sub $sp, $sp, 24
        sw $t0, 0($sp)
        sw $t1, 4($sp)
        sw $t2, 8($sp)
        sw $t3, 12($sp)
        sw $t4, 16($sp)
        sw $a0, 20($sp)
        
        jal puzzle_solving
                
        lw $t0, 0($sp)
        lw $t1, 4($sp)
        lw $t2, 8($sp)
        lw $t3, 12($sp)
        lw $t4, 16($sp)
        lw $a0, 20($sp)
        add $sp, $sp, 24

        j   interrupt_dispatch
non_intrpt:                             # was some non-interrupt
        li      $v0, PRINT_STRING
        la      $a0, non_intrpt_str
        syscall                         # print out an error message
# fall through to done

done:
        la      $k0, chunkIH
        lw      $a0, 0($k0)             # Restore saved registers
        lw      $v0, 4($k0)

.set noat
        move    $at, $k1                # Restore $at
.set at
        eret

/*
 * tabstop:	4
 * build: 	as binary.s -o binary.o
 *			ld -s -o binary binary.s
 */

	#---------------#
	# constants     #
	#---------------#
	.set	KERNEL,			0x80
	.set	SYS_WRITE,		4
	.set	SYS_EXIT,		1
	.set	STDOUT,			1
	.set	CHARBITS,		8
	.set	LINE_BYTES,		80

	.set	r.SYSCALL,		%eax

	#---------------#
	# functions     #
	#---------------#
	.global		_start
	.local		_output
	.local		_exit

#==============================================================================
	.section	.bss
#==============================================================================
	.align		4

# buffer one line of output. reserve byte to append '\n'
buffer_:		.space	LINE_BYTES
buffer_last_:	.space	1
buffer_end_:


#==============================================================================
	.section	.text
#==============================================================================
	.align 		4

	#---------------#
	# registers     #
	#---------------#
	.set	r.STACK, %esp
	.set	r.BIT,   %eax			# byte / bit loaded from argument string
	.set	rl.BIT,  %al
	.set	r.CHAR,  %ebx			# character being made from r.BITs
	.set	rl.CHAR, %bl
	.set	r.NBITS, %ecx			# number of bits not yet set in character
	.set	r.ARG,   %esi			# argument string
	.set	r.BUF,   %edi			# output buffer

/*
 ******************************************************************************
 * ENTRY: _start
 ******************************************************************************
 */

_start:

	cld								# access upward in memory

	addl	$8, r.STACK				# set stack to first user arg
	popl	r.ARG					# load first argument
	testl	r.ARG, r.ARG			# NULL?
	jz 		_exit					# yes, nothing to do

	leal	(buffer_), r.BUF		# load output memory address

	#------------------------------
	# loop through argument strings one byte at a time testing for 0 or 1
	#------------------------------
	xorl	r.BIT, r.BIT			# clear EAX. will only be using AL

.new_char:
	xorl	r.CHAR, r.CHAR			# clear char
	movl	$CHARBITS, r.NBITS		# num of char bits not set

.load_byte:
	lodsb							# load str byte into AL and inc str
	testb	rl.BIT, rl.BIT			# end of str?
	jz		.load_arg				# yes, get next arg

	# validate byte
	xorb	$0x30, rl.BIT			# convert digit to it's value
	cmpb	$1, rl.BIT				# value can only be 0 or 1
	jg		.load_byte				# greater than 1, get next byte

	# append represented bit to char
	shlb	$1, rl.CHAR				# shift char bits left
	andb	$1, rl.BIT				# set char val to binary val (0 or 1)
	orb		rl.BIT, rl.CHAR			# char |= bit

	# any more bits available to set in r.CHAR according to r.NBITS?
	loop	.load_byte				# yes, get next byte

	# all bits set, save char ...
	movb	rl.CHAR, rl.BIT			# copy char to EAX
	stosb							# store AL to EDI++ (r.BUF)

	# flush buffer if full. there must be at least one byte to append '\n'
	cmpl	$buffer_last_, r.BUF	# output byte address < buffer_last_ ?
	jl		.new_char				# yes, process next byte
	call	_output					# no, output buffer_
	leal	(buffer_), r.BUF		# reset buffer_ pointer
	jmp		.new_char

.load_arg:
	popl	r.ARG					# pop next argument from stack
	testl	r.ARG, r.ARG			# NULL?
	jnz 	.load_byte				# no, start processing string
	#------------------------------

.end:
	# no more arguments. output anything in buffer then exit
	call	_output


/******************************************************************************
 */


/*
 ******************************************************************************
 * STATIC FUNCTION: _exit
 *
 * Desc:		Exit program.
 ******************************************************************************
 */

_exit:

	.set	r.STATUS,	%ebx

	movl	$SYS_EXIT, r.SYSCALL	# exit system call
	xorl 	r.STATUS,  r.STATUS		# 0 == success
	int 	$KERNEL					# kernel interrupt

/******************************************************************************
 */


/*
 ******************************************************************************
 * STATIC FUNCTION: _output
 *
 * Desc:		Append '\n' to buffer_ and write to stdout.
 * Params:
 *		r.BUF: 	next available byte to write to in buffer_
 ******************************************************************************
 */

_output:

	# registers
	.set	r.FD,		%ebx
	.set	r.SRC,		%ecx
	.set	r.SIZE,		%edx

	pushal

	movb	$'\n, (r.BUF)			# terminate with '\n'
	incl	r.BUF					# point past linefeed to calculate length

	movl	$SYS_WRITE,	r.SYSCALL
	movl	$STDOUT,	r.FD
	leal	buffer_, 	r.SRC		# address of data to write
	movl	r.BUF, 		r.SIZE		# last byte address
	subl	r.SRC, 		r.SIZE		# strlen(buffer_)
	int 	$KERNEL

	popal
	ret

/******************************************************************************
 */


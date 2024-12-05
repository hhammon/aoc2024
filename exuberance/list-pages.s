.intel_syntax noprefix

.global list_pages

.section .text

# void list_pages(IntArray *values, IntArray *lengths, char *input_text, unsigned long input_len);
list_pages:
	push r12
	push r13
	push r14
	push r15

	# We only ever want the byte from these registers
	xor r12, r12
	xor r14, r14
	xor r15, r15

	# Init both arrays
	push rdx
	push rcx
	push rdi
	push rsi

	mov esi, 16
	call int_array_init

	mov rdi, qword ptr [rsp]
	mov esi, 16
	call int_array_init

	pop rsi
	pop rdi
	pop rcx
	pop rdx

	# int i = 0;
	xor r8, r8

	# bool in_number = false;
	xor r10, r10

	# int report_len = 0;
	xor r13, r13

	__list_pages_loop:
	cmp r8, rcx
	je __list_pages_loop_done
	
	# char c = input_text[i];
	mov r12b, byte ptr [rdx + r8]

	# if ((c >= '0') & (c <= '9'))
	cmp r12b, '0'
	setge r14b

	cmp r12b, '9'
	setle r15b

	test r14b, r15b
	jz __list_pages_loop_not_numeric

	# if (!in_number)
	test r10, r10
	jnz __list_pages_loop_already_in_number

	# in_number = true;
	mov r10, 1

	# num = 0; (num is in r9, but there is no reason to initialize before now)
	xor r9, r9

	__list_pages_loop_already_in_number:

	# c -= '0'
	and r12b, 0x0f

	# num = num * 10 + c;
	lea r9, [r9 + 4 * r9]
	add r9, r9
	add r9, r12

	jmp __list_pages_loop_continue

	__list_pages_loop_not_numeric:
	
	# if (!in_number) continue;
	test r10, r10
	jz __list_pages_loop_check_eol

	# If here, we have parsed to the end of a number,
	# and now need to append it to a list

	# in_number = false;
	xor r10, r10

	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9
	push r10

	mov rsi, r9
	call int_array_push

	pop r10
	pop r9
	pop r8
	pop rcx
	pop rdx
	pop rsi
	pop rdi

	# report_len++;
	inc r13

	__list_pages_loop_check_eol:
	# if (c == '\n')
	cmp r12b, '\n'
	jne __list_pages_loop_continue

	# int_array_push(lengths, report_len);
	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9
	push r10

	mov rdi, rsi
	mov rsi, r13
	call int_array_push

	pop r10
	pop r9
	pop r8
	pop rcx
	pop rdx
	pop rsi
	pop rdi

	# report_len = 0
	xor r13, r13

	__list_pages_loop_continue:
	inc r8
	jmp __list_pages_loop

	__list_pages_loop_done:

	# if (in_number)
	test r10, r10
	jz __list_pages_done

	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9
	push r10

	mov rsi, r9
	call int_array_push

	pop r10
	pop r9
	pop r8
	pop rcx
	pop rdx
	pop rsi
	pop rdi

	# report_len++;
	inc r13

	__list_pages_done:

	# int_array_push(lengths, report_len);
	mov rdi, rsi
	mov rsi, r13
	call int_array_push

	pop r15
	pop r14
	pop r13
	pop r12
	ret

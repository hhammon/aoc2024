.global _start
.intel_syntax noprefix

_start:

_start:
	mov rdi, QWORD PTR [RSP]
	lea rsi, [RSP + 8]
	call main

	mov edi, eax
	call exit

main:
	push rbp
	mov rbp, rsp
	sub rsp, 96

	cmp rdi, 2
	jne error

	# int fd = open_for_read(argv[1]); // [rsp + 0]
	mov rdi, qword ptr [rsi + 8]
	call open_for_read

	cmp eax, -1
	je error

	mov dword ptr [rsp], eax

	# unsigned long len = file_length(fd); // [rsp + 8]
	mov edi, eax
	call file_length
	mov qword ptr [rsp + 8], rax

	# char *buf = alloc_mem(len); // [rsp + 16]
	mov rdi, rax
	call alloc_mem

	test rax, rax
	jz error

	mov qword ptr [rsp + 16], rax

	# len = read(fd, buf, len);
	mov edi, dword ptr [rsp]
	mov rsi, rax
	mov edx, dword ptr [rsp + 8]
	call read

	cmp rax, -1
	je error

	mov qword ptr [rsp + 8], rax

	# IntArray left_list; // [rsp + 32]
	# IntArray right_list; // [rsp + 48]
	# create_lists(&left_list, &right_list, buf, len);
	mov rcx, rax
	mov rdx, qword ptr [rsp + 16]
	lea rdi, [rsp + 32]
	lea rsi, [rsp + 48]
	call create_lists

	# unsigned long sum = 0;
	xor eax, eax

	# int *left_list_ptr = left_list.ptr;
	mov rdi, qword ptr [rsp + 32]

	# int *right_list_ptr = right_list.ptr;
	mov rsi, qword ptr [rsp + 48]

	# int left_list_len = left_list.len;
	mov edx, dword ptr [rsp + 40]

	# int right_list_len = right_list.len;
	mov ecx, dword ptr [rsp + 56]

	# int i = 0;
	xor r8, r8

	__main_loop_outer:
	cmp r8, rdx
	je __main_loop_outer_done

	# int left_item = left_list_ptr[i]
	mov r10d, dword ptr [rdi + 4 * r8]

	# int j = 0;
	xor r9, r9

	__main_loop_inner:
	cmp r9, rcx
	je __main_loop_inner_done

	# if (left_item != right_list_ptr[j]) continue;
	cmp r10d, dword ptr [rsi + 4 * r9]
	je __main_loop_inner_add
	
	inc r9
	jmp __main_loop_inner

	__main_loop_inner_add:
	# sum += left_item;
	add rax, r10

	inc r9
	jmp __main_loop_inner

	__main_loop_inner_done:
	inc r8
	jmp __main_loop_outer

	__main_loop_outer_done:
	# char sum_str[32]; // [rsp + 64]
	# int digits = uint_to_string(sum, sum_str)
	mov rdi, rax
	lea rsi, [rsp + 64]
	call uint_to_string

	# sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 64], '\n'

	# print(sum_str, digits + 1;
	lea rdi, [rsp + 64]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 96
	pop rbp

	ret

.global _start
.intel_syntax noprefix

.section .text

_start:
	mov rdi, QWORD PTR [RSP]
	lea rsi, [RSP + 8]
	call main

	mov edi, eax
	call exit

# int main(int argc, char **argv);
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

	# int_array_qsort(&left_list);
	lea rdi, [rsp + 32]
	call int_array_qsort

	# int_array_qsort(&right_list);
	lea rdi, [rsp + 48]
	call int_array_qsort

	# unsigned long sum = 0
	xor eax, eax

	# int min_list_len = min(left_list.len, right_list.len);
	mov edx, dword ptr [rsp + 40]
	mov ecx, dword ptr [rsp + 56]
	cmp edx, ecx
	mov edi, edx
	cmova edi, ecx

	# int *left_list_ptr = left_list.ptr;
	mov r8, qword ptr [rsp + 32]

	# int *right_list_ptr = right_list.ptr;
	mov r9, qword ptr [rsp + 48]

	# int i = 0 
	xor esi, esi

	__main_loop:
	cmp esi, edi
	je __main_loop_done

	mov edx, dword ptr [r8 + 4 * rsi]
	sub edx, dword ptr [r9 + 4 * rsi]
	jns __main_loop_nonnegative

	neg edx

	__main_loop_nonnegative:
	add rax, rdx

	inc esi
	jmp __main_loop

	__main_loop_done:
	# char sum_str[32]; // [rsp + 64]
	# int digits = uint_to_string(sum, sum_str)
	mov rdi, rax
	lea rsi, [rsp + 64]
	call uint_to_string

	# sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 64], '\n'

	# print(sum_str, digits) + 1;
	lea rdi, [rsp + 64]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 96
	pop rbp

	ret

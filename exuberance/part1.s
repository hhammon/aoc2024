.global _start
.intel_syntax noprefix

.section .text

_start:
	mov rdi, qword ptr [rsp]
	lea rsi, [rsp + 8]
	call main

	mov edi, eax
	call exit

# int main(int argc, char **argv);
main:
	push rbp
	mov rbp, rsp
	sub rsp, 120

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

	# IntArray pages; // [rsp + 32]
	# IntArray lengths; // [rsp + 48]
	# list_pages(&pages, &lengths, buf, len);
	mov rcx, rax
	mov rdx, qword ptr [rsp + 16]
	lea rdi, [rsp + 32]
	lea rsi, [rsp + 48]
	call list_pages

	# RuleSet rule_set; // [rsp + 64]
	# (pages_idx, lengths_idx) = fill_rule_set(&pages, &lengths, &rule_set);

	lea rdi, [rsp + 32]
	lea rsi, [rsp + 48]
	lea rdx, [rsp + 64]
	call fill_rule_set

	# unsigned long sum = 0 // [rsp + 80]
	mov qword ptr [rsp + 80], 0

	# while (lengths_idx < lengths.len)
	__main_loop:
	cmp edx, dword ptr [rsp + 56]
	jge __main_loop_done

	# if (check_update(pages.ptr + pages_idx, lengths.ptr[lengths_idx], &rule_set))
	mov rdi, qword ptr [rsp + 48]
	mov esi, dword ptr [rdi + 4 * rdx]

	push rax
	push rdx
	push rsi

	mov rdi, qword ptr [rsp + 56] # [rsp + 32] but stack moved
	lea rdi, [rdi + 4 * rax]

	lea rdx, [rsp + 88] # [rsp + 64] but stack moved

	call check_update
	test eax, eax

	pop rsi
	pop rdx
	pop rax

	jz __main_loop_continue

	# Add middle page in update to sum. This is at index page_idx + update_len / 2
	mov rdi, qword ptr [rsp + 32]
	mov ecx, esi
	shr ecx
	add ecx, eax
	mov ecx, dword ptr [rdi + 4 * rcx]
	add qword ptr [rsp + 80], rcx

	__main_loop_continue:
	inc edx
	add eax, esi
	jmp __main_loop

	__main_loop_done:
	# char sum_str[32]; // [rsp + 88]
	# int digits = uint_to_string(sum, sum_str)
	mov rdi, qword ptr [rsp + 80]
	lea rsi, [rsp + 88]
	call uint_to_string

	# sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 88], '\n'

	# print(sum_str, digits) + 1;
	lea rdi, [rsp + 88]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 120
	pop rbp

	ret

# bool check_update(int *update, int update_len, RuleSet *rule_set);
check_update:
	# int i = 0;
	xor r8d, r8d

	__check_update_loop_outer:
	cmp r8d, esi
	jge __check_update_loop_outer_done

	# int j = i + 1;
	mov r9d, r8d
	inc r9d

	__check_update_loop_inner:
	cmp r9d, esi
	jge __check_update_loop_inner_done

	# if (is_rule(rule_set, update[j], update[i])) return false;
	push rdi
	push rsi
	push rdx
	push r8
	push r9

	push rdx
	mov esi, dword ptr [rdi + 4 * r9]
	mov edx, dword ptr [rdi + 4 * r8]
	pop rdi
	call is_rule

	pop r9
	pop r8
	pop rdx
	pop rsi
	pop rdi

	inc r9
	test eax, eax
	jz __check_update_loop_inner

	xor eax, eax
	ret

	__check_update_loop_inner_done:

	inc r8
	jmp __check_update_loop_outer

	__check_update_loop_outer_done:
	# return true;
	mov eax, 1
	ret

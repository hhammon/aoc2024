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
	sub rsp, 64

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

	# Move buf to rdi and len to rsi.
	mov rdi, qword ptr [rsp + 16]
	mov rsi, rax

	# unsigned long sum = 0; // [rsp + 24]
	mov qword ptr [rsp + 24], 0

	# int i = 0;
	xor ecx, ecx

	# Only the byte from these registers is wanted.
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11

	__main_loop_find_mul:
	# if (i + 4 > len) break;
	add ecx, 4
	cmp ecx, esi
	jg __main_loop_done
	sub ecx, 4

	cmp dword ptr [rdi + rcx], 0x286c756d # "mul("
	je __main_parse_nums

	inc ecx
	jmp __main_loop_find_mul

	__main_parse_nums:
	# i += 4; // Because i currently points to "mul("
	add ecx, 4

	# unsigned long num1 = 0;
	xor eax, eax

	# unsigned long num2 = 0;
	xor edx, edx

	# bool seen_comma = false;
	xor r8, r8

	__main_parse_nums_loop:
	cmp ecx, esi
	jge __main_loop_done

	# char c = buf[i];
	mov r9b, byte ptr [rdi + rcx]

	# i++;
	# Might as well do this here instead of in the ensuing mess.
	inc ecx

	# if (!seen_comma)
	test r8, r8
	jnz __main_parse_nums_loop_seen_comma

	# if (c == ',')
	cmp r9b, ','
	jne __main_parse_nums_loop_not_comma

	# There is no reason to verify that we are in a number,
	# since it will be 0 otherwise and make no difference.
	# So "mul(,)" can just as well be taken to be valid.

	# seen_comma = true;
	mov r8, 1

	# continue;
	jmp __main_parse_nums_loop

	__main_parse_nums_loop_not_comma:
	# if (c >= '0' & c <= '9')
	cmp r9b, '0'
	setge r10b
	
	cmp r9b, '9'
	setle r11b

	test r10b, r11b
	jz __main_loop_find_mul # Invalid, we can move on immediately.

	# c -= '0'
	and r9, 0x0f

	# num1 = num1 * 10 + c
	lea rax, [rax + 4 * rax]
	add rax, rax
	add rax, r9

	# continue;
	jmp __main_parse_nums_loop

	__main_parse_nums_loop_seen_comma:
	# if (c == ')')
	cmp r9b, ')'
	jne __main_parse_nums_loop_not_paren

	# There is no reason to verify that we are in a number,
	# since it will be 0 otherwise and make no difference.
	# So "mul(,)" can just as well be taken to be valid.

	# sum += num1 * num2
	mul rdx
	add [rsp + 24], rax

	jmp __main_loop_find_mul # Complete. Move on to the next.

	__main_parse_nums_loop_not_paren:
	# if (c >= '0' & c <= '9')
	cmp r9b, '0'
	setge r10b
	
	cmp r9b, '9'
	setle r11b

	test r10b, r11b
	jz __main_loop_find_mul # Invalid, we can move on immediately.

	# c -= '0'
	and r9, 0x0f

	# num2 = num2 * 10 + c
	lea rdx, [rdx + 4 * rdx]
	add rdx, rdx
	add rdx, r9

	# continue;
	jmp __main_parse_nums_loop

	__main_loop_done:

	# char sum_str[32]; // [rsp + 32]
	# int digits = uint_to_string(sum, sum_str)
	mov rdi, qword ptr [rsp + 24]
	lea rsi, [rsp + 32]
	call uint_to_string

	# sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 32], '\n'

	# print(sum_str, digits + 1);
	lea rdi, [rsp + 32]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 64
	pop rbp

	ret

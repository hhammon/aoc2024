.global _start
.intel_syntax noprefix

.section .rodata
search_word:
	.asciz "XMAS"

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
	sub rsp, 56

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

	# unsigned int count = count_word(word, buf, len)
	lea rdi, [search_word]
	mov rsi, qword ptr [rsp + 16]
	mov rdx, rax
	call count_word

	# char count_str[32]; // [rsp + 24]
	# int digits = uint_to_string(count, count_str)
	mov rdi, rax
	lea rsi, [rsp + 24]
	call uint_to_string

	# count_str[digits] = '\n'
	mov byte ptr [rsp + rax + 24], '\n'

	# print(count_str, digits + 1);
	lea rdi, [rsp + 24]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 56
	pop rbp

	ret


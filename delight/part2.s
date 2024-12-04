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
	sub rsp, 72

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

	# (unsigned int width, unsigned int height) = get_dimensions(buf, len);
	# ([rsp + 24], [rsp + 28])
	mov rdi, qword ptr [rsp + 16]
	mov esi, eax
	call get_dimensions
	mov dword ptr [rsp + 24], eax
	mov dword ptr [rsp + 28], edx

	# unsigned long count = 0; // [rsp + 32]
	mov qword ptr [rsp + 32], 0

	# int x = 1;
	mov r8d, 1

	__main_loop_outer:
	inc r8d
	cmp r8d, dword ptr [rsp + 24]
	je __main_loop_outer_done
	dec r8d

	# int y = 1;
	mov r9d, 1

	__main_loop_inner:
	inc r9d
	cmp r9d, dword ptr [rsp + 28]
	je __main_loop_inner_done
	dec r9d

	# if (get_char_at_coords(buf, width, x, y) != 'A') continue;
	mov rdi, qword ptr [rsp + 16]
	mov esi, dword ptr [rsp + 24]
	mov edx, r8d
	mov ecx, r9d

	push r8
	push r9

	call get_char_at_coords

	pop r9
	pop r8

	cmp al, 'A'
	jne __main_loop_inner_continue

	# char corners[4] = {
	#     get_char_at_coords(buf, width, x - 1, y - 1), 
	#     get_char_at_coords(buf, width, x + 1, y - 1), 
	#     get_char_at_coords(buf, width, x + 1, y + 1), 
	#     get_char_at_coords(buf, width, x - 1, y + 1) 
	# }; // [rsp + 12]

	mov rdi, qword ptr [rsp + 16]
	mov esi, dword ptr [rsp + 24]
	mov edx, r8d
	mov ecx, r9d

	dec edx
	dec ecx

	push r8
	push r9

	call get_char_at_coords

	pop r9
	pop r8

	mov byte ptr [rsp + 12], al

	mov rdi, qword ptr [rsp + 16]
	mov esi, dword ptr [rsp + 24]
	mov edx, r8d
	mov ecx, r9d

	inc edx
	dec ecx

	push r8
	push r9

	call get_char_at_coords

	pop r9
	pop r8

	mov byte ptr [rsp + 13], al

	mov rdi, qword ptr [rsp + 16]
	mov esi, dword ptr [rsp + 24]
	mov edx, r8d
	mov ecx, r9d

	inc edx
	inc ecx

	push r8
	push r9

	call get_char_at_coords

	pop r9
	pop r8

	mov byte ptr [rsp + 14], al

	mov rdi, qword ptr [rsp + 16]
	mov esi, dword ptr [rsp + 24]
	mov edx, r8d
	mov ecx, r9d

	dec edx
	inc ecx

	push r8
	push r9

	call get_char_at_coords

	pop r9
	pop r8

	mov byte ptr [rsp + 15], al

	xor eax, eax
break:
	cmp dword ptr [rsp + 12], 0x4d53534d # "MSSM"
	sete al
	add qword ptr [rsp + 32], rax

	cmp dword ptr [rsp + 12], 0x4d4d5353 # "SSMM"
	sete al
	add qword ptr [rsp + 32], rax

	cmp dword ptr [rsp + 12], 0x534d4d53 # "SMMS"
	sete al
	add qword ptr [rsp + 32], rax

	cmp dword ptr [rsp + 12], 0x53534d4d # "MMSS"
	sete al
	add qword ptr [rsp + 32], rax

	__main_loop_inner_continue:
	inc r9d
	jmp __main_loop_inner

	__main_loop_inner_done:

	inc r8d
	jmp __main_loop_outer

	__main_loop_outer_done:

	# char count_str[32]; // [rsp + 40]
	# int digits = uint_to_string(count, count_str)
	mov rdi, qword ptr [rsp + 32]
	lea rsi, [rsp + 40]
	call uint_to_string

	# count_str[digits] = '\n'
	mov byte ptr [rsp + rax + 40], '\n'

	# print(count_str, digits + 1);
	lea rdi, [rsp + 40]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 72
	pop rbp

	ret


# (unsigned int, unsigned int) get_dimensions(char *word_search, unsigned int len);
# Returns (width, height) in (rax, rdx). New line characters will be counted in width for
# simplicity in other calculations.
get_dimensions:
	# int i = 0
	xor ecx, ecx

	xor edx, edx

	__get_dimensions_loop:
	cmp ecx, esi
	je __get_dimensions_loop_done
	
	# char c = word_search[i]
	mov dl, byte ptr [rdi + rcx]

	# i++;
	inc ecx
	
	# if (c == '\n') break;
	cmp dl, '\n'
	jne __get_dimensions_loop

	__get_dimensions_loop_done:

	# return (i, (len + 1) / i); // Add 1 to len because last line will not have a new line
	xor edx, edx
	mov eax, esi
	inc eax
	div ecx
	mov edx, eax

	mov eax, ecx

	ret

# char get_char_at_coords(char *word_search, unsigned int width, unsigned int x, unsigned int y);
get_char_at_coords:
	# return word_search[y * width + x]
	mov eax, esi
	xchg ecx, edx
	mul edx
	add ecx, eax

	xor eax, eax
	mov al, byte ptr [rdi + rcx]
	ret

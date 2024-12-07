.intel_syntax noprefix

.global exit
.global error
.global print
.global open_for_read
.global file_length
.global read
.global alloc_mem
.global free_mem
.global uint_to_string
.global mem_copy

.section .text

# void exit(int code);
exit:
	mov eax, 60
	syscall

# For this project, this will be used as a catch-all jump point
error:
	mov edi, 1;
	call exit

# void print(char *str, int len);
print:
	# write(1, str, len);utils
	mov eax, 1
	mov edx, esi
	mov rsi, rdi
	mov edi, 1
	syscall
	ret

# unsigned int open_for_read(char *file_name);
# Returns file descriptor or -1 if error occured
open_for_read:
	# open(file_name, O_RDONLY, 0)
	xor edx, edx
	xor esi, esi
	mov eax, 2
	syscall
	ret

# unsigned long file_length(unsigned int fd);
file_length:
	# Create space for stat struct
	sub rsp, 152
	mov rsi, rsp
	mov eax, 5
	syscall

	test eax, eax
	jnz error

	# Get file size in bytes from stat struct
	mov rax, qword ptr [rsp+48]

	add rsp, 152
	ret

# int read(unsigned int fd, char *buf, int n_bytes)
# Returns number of bytes read
read:
	xor eax, eax
	syscall
	ret

# void *alloc_mem(unsigned long n_bytes);
# For this project, we'll just allocate directly from the OS
# rather than implement an allocator.
alloc_mem:
	# mmap(NULL, n_bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
	mov eax, 9
	mov rsi, rdi
	xor edi, edi
	mov edx, 3
	mov r10d, 34
	mov r8, -1
	xor r9, r9
	syscall
	ret

# void free_mem(void *ptr, unsigned long n_bytes);
free_mem:
	# munmap(ptr, n_bytes);
	mov eax, 11
	syscall
	ret

# int uint_to_string(unsigned long num, char *dest);
# Returns the length of the string.
uint_to_string:
	push rbp
	mov rbp, rsp
	sub rsp, 32
	
	mov rax, rdi
	xor ecx, ecx
	
	__uint_to_string_convert_loop:
	# Magic to divide by 10 efficiently
	movabs rdx, 0xCCCCCCCCCCCCCCCD
	mul rdx
	shr rdx, 3
	mov rax, rdx

	# Multiply by 10 and subtract for remainder
	lea rdx, [rdx + rdx * 4]
	add rdx, rdx
	sub rdi, rdx

	# Convert to ascii and prepend to string
	or dil, 0x30
	mov byte ptr [rbp + rcx], dil
	dec rcx

	mov rdi, rax
	test rax, rax
	jnz __uint_to_string_convert_loop

	# After the loop, rcx contains the negative string length
	# Get the pointer to the start of the string
	lea rdx, [rbp + rcx + 1]
	
	# Get length for return later
	mov rax, rcx
	neg rax

	xor ecx, ecx

	__uint_to_string_copy_loop:
	cmp rcx, rax
	je __uint_to_string_copy_done

	mov dil, byte ptr [rdx + rcx]
	mov byte ptr [rsi + rcx], dil

	inc rcx
	jmp __uint_to_string_copy_loop

	__uint_to_string_copy_done:
	add rsp, 32
	pop rbp

	ret

# void mem_copy(void *dest, void *src, unsigned long num_bytes);
mem_copy:
	mov rcx, rdx
	cld
	rep movsb
	ret

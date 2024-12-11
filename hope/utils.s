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
.global long_array_init
.global long_array_free
.global long_array_push
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

# struct LongArray {
# 	long *ptr; // bytes 0-7
# 	unsigned int len; //bytes 8-11
# 	unsigned int cap; // bytes 12-15
# }
# sizeof(LongArray) = 16
# This struct should always be quadword aligned,
# if not double-quadword aligned.

# void long_array_init(LongArray *arr, unsigned int cap);
long_array_init:
	# No reason not to round cap up to the full page,
	# or multiple of 512
	xor eax, eax
	test esi, 0x1ff
	setnz al
	and esi, 0xfffffe00
	shl eax, 9
	add esi, eax

	# Attempt to allocate cap * 8 bytes of memory
	push rdi
	push rsi

	lea rdi, [rsi * 8]
	call alloc_mem
	
	test rax, rax
	jz error

	# If here, memory has been successfully allocated
	pop rsi
	pop rdi

 	# store pointer to allocated memory at arr->ptr
	mov qword ptr [rdi], rax
	# arr->len = 0
	mov dword ptr [rdi + 8], 0
	# arr->cap = cap
	mov dword ptr [rdi + 12], esi

	ret

# void long_array_free(LongArray *arr);
long_array_free:
	mov rax, rdi
	mov rdi, qword ptr [rax]
	mov esi, dword ptr [rax + 12]
	shl rsi, 3

	mov qword ptr [rax], 0
	mov qword ptr [rax + 8], 0

	call free_mem
	ret

# void long_array_push(LongArray *arr, long item);
long_array_push:
	# We need to realloc if arr->len == arr->cap
	mov ecx, dword ptr [rdi + 8]
	mov edx, dword ptr [rdi + 12]
	cmp ecx, edx
	jne __long_array_push_push

	# Ensure cap is greater than 0 so doubling will guarantee a larger array
	test edx, edx
	jnz __long_array_push_realloc

	mov edx, 1

	__long_array_push_realloc:

	# Double cap
	add edx, edx

	# No reason not to round cap up to the full page,
	# or multiple of 512
	xor eax, eax
	test edx, 0x1ff
	setnz al
	and edx, 0xfffffe00
	shl eax, 9
	add edx, eax

	# Attempt to allocate cap * 8 bytes of memory
	push rdi
	push rsi
	push rcx
	push rdx

	lea rdi, [rdx * 8]
	call alloc_mem

	cmp rax, -1
	je error

	# If here, memory has been successfully allocated
	pop rdx
	pop rcx 
	pop rsi
	pop rdi

	# Copy arr->len items from arr->ptr to [rax]
	mov r8, rsi
	mov r9, rdi
	mov rsi, qword ptr [rdi]
	mov rdi, rax
	mov r10, rcx
	
	cld
	rep movsq

	mov rsi, r8
	mov rdi, r9
	mov rcx, r10

	# free_mem(arr->ptr, arr->cap);
	push rax
	push rdi
	push rsi
	push rcx
	push rdx

	mov esi, dword ptr [rdi + 12]
	call free_mem

	pop rdx
	pop rcx
	pop rsi
	pop rdi
	pop rax

	# Update arr->ptr and arr->cap
	mov qword ptr [rdi], rax
	mov dword ptr [rdi + 12], edx

	__long_array_push_push:

	mov rax, qword ptr [rdi]

	# arr->ptr[arr->len] = item;
	mov qword ptr [rax + 8 * rcx], rsi

	# arr->len++;
	inc ecx
	mov dword ptr [rdi + 8], ecx

	ret

# void mem_copy(void *dest, void *src, unsigned long num_bytes);
mem_copy:
	mov rcx, rdx
	cld
	rep movsb
	ret
.intel_syntax noprefix
.global _start

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
	sub rsp, 112

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

	# LongArray values; // [rsp + 32]
	# LongArray lengths; // [rsp + 48]
	# list_equations(&values, &lengths, buf, len)
	lea rdi, [rsp + 32]
	lea rsi, [rsp + 48]
	mov rdx, qword ptr [rsp + 16]
	mov rcx, rax
	call list_equations

	# int i = 0; // [rsp + 24]
	# unsigned int len_sum = 0; // [rsp + 28]
	mov qword ptr [rsp + 24], 0

	# unsigned long sum = 0; // [rsp + 64]
	mov qword ptr [rsp + 64], 0

	__main_loop:
	mov ecx, dword ptr [rsp + 24]
	cmp ecx, dword ptr [rsp + 56]
	jge __main_loop_done

	# if (can_equate(&values.ptr[len_sum], lengths.ptr[i])) sum += values.ptr[len_sum];
	mov rdi, qword ptr [rsp + 32]
	mov eax, dword ptr [rsp + 28]
	mov rsi, qword ptr [rsp + 48]
	mov ecx, dword ptr [rsp + 24]
	lea rdi, [rdi + 8 * rax]
	mov rsi, qword ptr [rsi + 8 * rcx]

	push rdi
	push rsi

	call can_equate

	pop rsi
	pop rdi

	# len_sum += lengths.ptr[i])
	add dword ptr [rsp + 28], esi

	# i++;
	inc dword ptr [rsp + 24]
	
	test al, al
	jz __main_loop

	mov rax, qword ptr [rdi]
	add qword ptr [rsp + 64], rax

	jmp __main_loop

	__main_loop_done:
	# char sum_str[32]; // [rsp + 72]
	# int digits = uint_to_string(sum, sum_str)
	mov rdi, qword ptr [rsp + 64]
	lea rsi, [rsp + 72]
	call uint_to_string

	# sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 72], '\n'

	# print(sum_str, digits) + 1;
	lea rdi, [rsp + 72]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 112
	pop rbp

	ret

# bool can_equate(unsigned long *values, int len);
can_equate:
	cmp esi, 1
	jge __can_equate_has_values

	xor eax, eax
	ret

	__can_equate_has_values:

	push rbp
	mov rbp, rsp
	sub rsp, 32

	# Move values to stack at [rsp]
	mov qword ptr [rsp], rdi
	
	# Move len to stack at [rsp + 8]
	mov dword ptr [rsp + 8], esi
	
	# long ops = 0; // [rsp + 16]
	mov qword ptr [rsp + 16], 0

	# long ops_mask = (1 << (len - 2)) - 1; // [rsp + 24]
	mov ecx, esi
	sub ecx, 2
	mov eax, 1
	shl rax, cl
	dec rax
	mov qword ptr [rsp + 24], rax

	# do ... while (ops & ops_mask != 0)
	__can_equate_loop:
	# if (check_equation(values, ops, len)) return true;
	mov rdi, qword ptr [rsp]
	mov rsi, qword ptr [rsp + 16]
	mov edx, dword ptr [rsp + 8]
	call check_equation
	test al, al
	jz __can_equate_loop_continue

	mov rsp, rbp
	pop rbp
	ret

	__can_equate_loop_continue:
	# ops++;
	mov rax, qword ptr [rsp + 16]
	inc rax
	mov qword ptr [rsp + 16], rax

	test rax, qword ptr [rsp + 24]
	jnz __can_equate_loop

	# return false;
	xor eax, eax

	mov rsp, rbp
	pop rbp
	ret

# bool check_equation(unsigned long *values, long ops, int len);
# len should never be so large that ops can't be 64 bit bit-array.
check_equation:
	# if (len < 2) return false
	cmp edx, 2
	jge __check_equation_has_values

	xor eax, eax
	ret

	__check_equation_has_values:

	# Move len to r8 because rdx is written in mul instructions
	mov r8, rdx

	# unsigned long lhs = values[0]
	mov r9, qword ptr [rdi]

	# long rhs = values[1];
	mov rax, qword ptr [rdi + 8]

	cmp edx, 2
	je __check_equation_loop_return

	# int i = 2;
	mov ecx, 2

	__check_equation_loop:
	# if (ops & 1) rhs *= values[i];
	test rsi, 1
	jz __check_equation_loop_add

	mul qword ptr [rdi + 8 * rcx]

	jmp __check_equation_loop_continue	

	__check_equation_loop_add:
	add rax, qword ptr [rdi + 8 * rcx]

	__check_equation_loop_continue:
	shr rsi
	inc ecx
	cmp ecx, r8d
	jl __check_equation_loop

	__check_equation_loop_return:
	# return lhs == rhs
	mov rdx, rax
	xor eax, eax
	cmp rdx, r9
	sete al
	ret

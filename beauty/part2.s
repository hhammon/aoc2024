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

	# IntArray values; // [rsp + 32]
	# IntArray lengths; // [rsp + 48]
	# create_reports(&values, &lengths, buf, len);
	mov rcx, rax
	mov rdx, qword ptr [rsp + 16]
	lea rdi, [rsp + 32]
	lea rsi, [rsp + 48]
	call create_reports

	# unsigned long safe_reports = 0;
	xor eax, eax

	# int report_count = lengths.len;
	mov edi, dword ptr [rsp + 56]

	# int i = 0;
	xor esi, esi

	# int report_val_idx = 0;
	xor edx, edx;

	# int *values_ptr = values.ptr;
	mov r8, qword ptr [rsp + 32]

	# int *lengths_ptr = lengths.ptr;
	mov r9, qword ptr [rsp + 48]

	__main_loop:
	cmp esi, edi
	je __main_loop_done

	# safe_reports += check_report_dampened(&values[report_val_idx], lengths[i])
	mov ecx, dword ptr [r9 + 4 * rsi]

	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9
	push rax

	lea rdi, [r8 + 4 * rdx]
	mov esi, ecx
	call check_report_dampened

	mov edx, eax
	pop rax
	add rax, rdx

	pop r9
	pop r8
	pop rcx
	pop rdx
	pop rsi
	pop rdi

	# report_val_idx += lengths[i];
	add edx, ecx

	# i++;
	inc esi

	jmp __main_loop

	__main_loop_done:
	# char safe_reports_str[32]; // [rsp + 64]
	# int digits = uint_to_string(sum, safe_reports_str)
	mov rdi, rax
	lea rsi, [rsp + 64]
	call uint_to_string

	# sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 64], '\n'

	# print(sum_str, digits + 1);
	lea rdi, [rsp + 64]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 96
	pop rbp

	ret

# bool check_report(int *report, int len)
check_report:
	cmp esi, 2
	jge __check_report_long_enough

	mov eax, 1
	ret

	__check_report_long_enough:
	# bool is_ascending = report[0] < report[1];
	xor ecx, ecx
	mov edx, dword ptr [rdi]
	cmp edx, dword ptr [rdi + 4]
	setl cl

	# int i = 0;
	xor edx, edx

	xor r10, r10
	xor r11, r11

	# len--;
	# This is to because there are len - 1 adjacent pairs in len items.
	dec esi

	__check_report_loop:
	# int diff = report[i] - report[i++];
	mov r8d, dword ptr [rdi + 4 * rdx]
	inc edx
	sub r8d, dword ptr [rdi + 4 * rdx]

	# if (is_ascending) diff = -diff;
	test ecx, ecx
	jz __check_report_loop_verify_pair

	neg r8d

	__check_report_loop_verify_pair:
	# if (!(diff <= 3 & diff >= 1)) return false;
	cmp r8d, 3
	setle r10b

	cmp r8d, 1
	setge r11b

	test r10, r11
	jnz __check_report_loop_continue

	xor eax, eax
	ret

	__check_report_loop_continue:
	cmp edx, esi
	jl __check_report_loop

	# If here, the report is safe.
	mov eax, 1
	ret

# bool check_report_dampened(int *report, int len);
check_report_dampened:
	push rdi
	push rsi

	call check_report

	pop rsi
	pop rdi

	test eax, eax
	jz __check_report_dampened_removals

	ret

	__check_report_dampened_removals:
	# int dampened_len = len - 1
	mov ecx, esi
	dec ecx

	# Create stack space to copy report
	# int dampened_report[dampened_len];
	lea rdx, [4 * rcx]
	push rbp
	mov rbp, rsp
	sub rsp, rdx

	# int i = 0
	xor edx, edx

	__check_report_dampened_loop:
	cmp edx, esi
	je __check_report_dampened_loop_done

	# int j = 0;
	xor r8, r8

	# int copy_idx = 0;
	xor r9, r9

	__check_report_dampened_copy_loop:
	# if (j == i) continue;
	cmp r8, rdx
	je __check_report_dampened_copy_loop_continue

	mov r10d, dword ptr [rdi + 4 * r8]
	mov dword ptr [rsp + 4 * r9], r10d

	inc r9

	__check_report_dampened_copy_loop_continue:
	inc r8
	
	cmp r8, rsi
	jl __check_report_dampened_copy_loop

	# if (check_report(dampened_report, dampened_len)) return true;

	push rdi
	push rsi
	push rdx
	push rcx

	# The stack has moved by 32 bytes from pushes
	lea rdi, [rsp + 32]
	mov esi, ecx
	call check_report

	pop rcx
	pop rdx
	pop rsi
	pop rdi

	test eax, eax
	jnz __check_report_dampened_return

	inc edx
	jmp __check_report_dampened_loop

	__check_report_dampened_loop_done:

	# return false
	xor eax, eax

	__check_report_dampened_return:

	mov rsp, rbp
	pop rbp

	ret

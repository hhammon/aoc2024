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

	# Round len to multiple of 128 for use in SSE instructions
	xor edx, edx
	test eax, 0x7f
	setnz dl
	and eax, 0xffffff80
	shl edx, 7
	add eax, edx

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

	test rax, rax
	jz error

	mov edx, 0x30303030 # "0000"
	movd xmm1, edx
	pshufd xmm1, xmm1, 0 # xmm1 now contains 16 '0' bytes

	xor ecx, ecx
	mov rdi, qword ptr [rsp + 16]

	__main_normalize_buf_loop:
	movdqu xmm0, xmmword ptr [rdi + rcx]
	psubb xmm0, xmm1
	movdqu xmmword ptr [rdi + rcx], xmm0
	
	add rcx, 16
	cmp rcx, rax
	jl __main_normalize_buf_loop

	# unsigned long check_sum = check_sum_after_pack(buf, len);
	mov rsi, rax
	call check_sum_after_pack

	# char check_sum_str[32]; // [rsp + 32]
	# int digits = uint_to_string(check_sum, check_sum_str)
	mov rdi, rax
	lea rsi, [rsp + 32]
	call uint_to_string

	# check_sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 32], '\n'

	# print(check_sum_str, digits) + 1;
	lea rdi, [rsp + 32]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 64
	pop rbp

	ret
	
# unsigned long check_sum_after_pack(char *disk_map, unsigned int len);
check_sum_after_pack:
	# if (len < 3) return 0;
	# The checksum from only a single file is 0
	cmp esi, 3
	jge __check_sum_after_pack_has_data

	xor eax, eax
	ret

	__check_sum_after_pack_has_data:
	push rbx
	
	# unsigned long check_sum = 0;
	xor ebx, ebx

	# int gap_idx = 1;
	mov ecx, 1

	# int file_id = (len - 1) / 2;
	dec esi
	shr esi

	# unsigned char gap = disk_map[gap_idx]
	xor r8, r8
	mov r8b, byte ptr [rdi + rcx]

	# unsigned char file_len = disk_map[file_id * 2]
	xor r9, r9
	mov r9b, byte ptr [rdi + 2 * rsi]

	# int block_pos = disk_map[0]; // Length of the first file.
	xor r10, r10
	mov r10b, byte ptr [rdi]

	# while (2 * file_id > gap_idx) //Gauranteed to begin true from above check on len.
	__check_sum_after_pack_loop:
	# if (gap == 0) advance to next and continue
	test r8b, r8b
	jnz __check_sum_after_pack_loop_gap_unfilled

	# Before advance gap idx forward by 2, the file between needs to be processed
	inc ecx
	mov r8b, byte ptr [rdi + rcx] # gapped_file_len
	shr ecx # gapped_file_id

	# We may have advanced into the file already being processed and need to finish it
	cmp ecx, esi
	cmove r8, r9

	__check_sum_after_pack_loop_process_file_between_gaps_loop:
	test r8b, r8b
	jz __check_sum_after_pack_loop_process_file_between_gaps_loop_done

	# check_sum += gapped_file_id * block_pos;
	mov rax, rcx
	mul r10
	add rbx, rax

	# block_pos++
	inc r10

	# gapped_file_len--;
	dec r8b

	jmp __check_sum_after_pack_loop_process_file_between_gaps_loop

	__check_sum_after_pack_loop_process_file_between_gaps_loop_done:
	# Restore gap_idx and advance it
	shl ecx
	inc ecx

	# gap = disk_map[gap_idx];
	mov r8b, byte ptr [rdi + rcx]

	jmp __check_sum_after_pack_loop_continue

	# Process file until (file_len == 0 || gap == 0)
	__check_sum_after_pack_loop_gap_unfilled:
	test r9b, r9b
	jz __check_sum_after_pack_loop_file_done

	test r8b, r8b
	jz __check_sum_after_pack_loop_continue

	# check_sum += file_id * block_pos;
	mov rax, rsi
	mul r10
	add rbx, rax

	# block_pos++
	inc r10

	# file_len--;
	dec r9b

	# gap--;
	dec r8b

	jmp __check_sum_after_pack_loop_gap_unfilled

	__check_sum_after_pack_loop_file_done:
	# file_id--;
	dec esi

	# file_len = disk_map[file_id * 2]
	mov r9b, byte ptr [rdi + 2 * rsi]

	__check_sum_after_pack_loop_continue:
	mov r11, rsi
	add r11, r11
	cmp r11, rcx
	jg __check_sum_after_pack_loop

	mov rax, rbx

	pop rbx

	ret


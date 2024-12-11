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
	# int *block_indices = alloc_mem(len * 4);
	push rdi
	push rsi

	lea rdi, [4 * rsi]
	call alloc_mem

	pop rdx # len moved to edx	
	pop rdi

	push rdx # To recover len before returning when deallocating

	mov rsi, rax # block_indices in rsi

	# Initilize block_indices to be a running sum of file or gap lengths

	# int block_index = 0
	xor eax, eax

	# int i = 0;
	xor ecx, ecx

	# Only byte used from these registers
	xor r8, r8
	xor r10, r10

	__check_sum_after_pack_init_loop:
	# block_indices[i] = block_index;
	mov dword ptr [rsi + 4 * rcx], eax

	# block_index += disk_map[i];
	mov r8b, byte ptr [rdi + rcx]
	add eax, r8d

	# i++;
	inc ecx
	cmp ecx, edx
	jl __check_sum_after_pack_init_loop

	# for (int file_id = (len - 1) / 2; file_id > 0; i--) # Guaranteed a run from check on len before
	mov ecx, edx
	dec ecx
	shr ecx

	__check_sum_after_pack_loop_outer:
	# unsigned char file_len = disk_map[file_id * 2];
	mov r8b, byte ptr [rdi + 2 * rcx]

	# for (int gap_idx = 1; gap_idx < file_id * 2; gap_idx += 2)
	mov r9, 1

	__check_sum_after_pack_loop_inner:
	# unsigned char gap_len = disk_map[gap_idx];
	mov r10b, byte ptr [rdi + r9]

	# if (gap_len < file_len) continue;
	cmp r10b, r8b
	jl __check_sum_after_pack_loop_inner_continue

	# Here, the file is being moved into the gap.
	# block_index = block_indices[gap_idx];
	mov eax, dword ptr [rsi + 4 * r9]

	# block_indices[2 * file_id] = block_index;
	mov dword ptr [rsi + 8 * rcx], eax

	# block_indices[gap_idx] += file_len;
	add dword ptr [rsi + 4 * r9], r8d

	# disk_map[gap_idx] -= file_len;
	sub byte ptr [rdi + r9], r8b

	# break;
	jmp __check_sum_after_pack_loop_outer_continue

	__check_sum_after_pack_loop_inner_continue:
	add r9d, 2
	mov r11, rcx
	add r11, r11
	cmp r9, r11
	jl __check_sum_after_pack_loop_inner

	__check_sum_after_pack_loop_outer_continue:
	dec ecx
	jnz __check_sum_after_pack_loop_outer

	# unsigned long check_sum = 0;
	xor r8, r8

	# for (int file_id = (len - 1) / 2; file_id > 0; i--) # Guaranteed a run from check on len before
	mov ecx, edx
	dec ecx
	shr ecx

	__check_sum_after_pack_add_loop_outer:
	# int block_index = block_indices[file_len * 2]
	mov r9d, dword ptr [rsi + 8 * rcx]

	# unsigned char file_len = disk_map[file_len * 2]
	mov r10b, byte ptr [rdi + 2 * rcx]

	# for (int i = 0; i < file_len; i++)
	xor r11, r11

	__check_sum_after_pack_add_loop_inner:
	cmp r11, r10
	jge __check_sum_after_pack_add_loop_inner_done

	# check_sum += file_id * block_index;
	mov eax, ecx
	mul r9
	add r8, rax

	# block_index++;
	inc r9d
	# i++;
	inc r11

	jmp __check_sum_after_pack_add_loop_inner

	__check_sum_after_pack_add_loop_inner_done:
	dec ecx
	jnz __check_sum_after_pack_add_loop_outer

	# free_mem(block_indices, len)
	mov rdi, rsi
	pop rsi
	push r8
	call free_mem

	pop rax

	ret

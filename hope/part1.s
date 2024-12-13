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

	# Grid map; // [rsp + 32]
	# grid_init(&map, buf, len)
	lea rdi, [rsp + 32]
	mov rsi, qword ptr [rsp + 16]
	mov rdx, rax
	call grid_init

	# Grid antinodes; // [rsp + 48]
	# antinodes will be manually set up to the dimensions of map

	# Copy width and height from map into antinodes
	mov rax, qword ptr [rsp + 40]
	mov qword ptr [rsp + 56], rax

	# antinodes.data = alloc_mem(len)
	mov rdi, qword ptr [rsp + 8]
	call alloc_mem

	test rax, rax
	jz error

	mov qword ptr [rsp + 48], rax

	# find_antinodes(&map, &antinodes);
	lea rdi, [rsp + 32]
	lea rsi, [rsp + 48]
	call find_antinodes

	# int antinode_count = grid_count(&antinodes, '#');
	lea rdi, [rsp + 48]
	mov esi, '#'
	call grid_count

	# char sum_str[32]; // [rsp + 64]
	# int digits = uint_to_string(sum, sum_str)
	mov rdi, rax
	lea rsi, [rsp + 64]
	call uint_to_string

	# sum_str[digits] = '\n'
	mov byte ptr [rsp + rax + 64], '\n'

	# print(sum_str, digits) + 1;
	lea rdi, [rsp + 64]
	mov esi, eax
	inc esi
	call print

	xor eax, eax
	add rsp, 96
	pop rbp

	ret

# struct Coordinates {
#     int x; // bytes 0-3
#     int y; // bytes 4-7
# }

# sizeof Coordinates = 8
# This struct should always be quadword aligned.
# For simplicity, we'll represent point-wise arithmetic operations on the struct itself.

# void find_antinodes(Grid *map, Grid *antinodes);
find_antinodes:
	# char freq = '0';
	mov edx, '0'

	__find_antinodes_loop:
	# find_antinodes_at_freq(map, antinodes, freq);
	push rdi
	push rsi
	push rdx
	
	call find_antinodes_at_freq

	pop rdx
	pop rsi
	pop rdi

	inc edx
	cmp edx, ':' # '9' + 1
	jl __find_antinodes_loop
	jg __find_antinodes_loop_past_numeric

	mov edx, 'A'
	jmp __find_antinodes_loop

	__find_antinodes_loop_past_numeric:
	cmp edx, '[' # 'Z' + 1
	jl __find_antinodes_loop
	jg __find_antinodes_loop_past_upper

	mov edx, 'a'
	jmp __find_antinodes_loop

	__find_antinodes_loop_past_upper:
	cmp edx, '{'
	jl __find_antinodes_loop

	ret

# void find_antinodes_at_freq(Grid *map, Grid *antinodes, char freq);
find_antinodes_at_freq:
	push rbp
	mov rbp, rsp
	sub rsp, 48

	# Move antinodes to stack at [rsp]
	mov qword ptr [rsp], rsi

	# LongList antennas; [rsp + 16]
	# grid_find_all(map, &antennas, freq);
	lea rsi, [rsp + 16]
	call grid_find_all

	# if (antennas.len < 2) return;
	cmp dword ptr [rsp + 24], 2
	jl __find_antinodes_at_freq_loop_done

	# int i = 0; // [rsp + 8]
	mov dword ptr [rsp + 8], 0

	__find_antinodes_at_freq_loop_outer:
	# Coordinates antenna1 = (Coordinates)antennas->ptr[i]; // [rsp + 32]
	mov rax, qword ptr [rsp + 16]
	mov ecx, dword ptr [rsp + 8]
	mov rax, qword ptr [rax + 8 * rcx]
	mov qword ptr [rsp + 32], rax

	# int j = i + 1; // [rsp + 12]
	inc ecx
	mov dword ptr [rsp + 12], ecx

	__find_antinodes_at_freq_loop_inner:
	# Coordinates antenna2 = (Coordinates)antennas->ptr[j];
	mov rdx, qword ptr [rsp + 16]
	mov ecx, dword ptr [rsp + 12]
	mov rdx, qword ptr [rdx + 8 * rcx]

	# find_antinodes_for_antennas(antinodes, antenna1, antenna2);
	mov rdi, qword ptr [rsp]
	mov rsi, qword ptr [rsp + 32]
	call find_antinodes_for_antennas

	mov ecx, dword ptr [rsp + 12]
	inc ecx
	mov dword ptr [rsp + 12], ecx
	cmp ecx, dword ptr [rsp + 24]
	jl __find_antinodes_at_freq_loop_inner

	inc dword ptr [rsp + 8]
	mov eax, dword ptr [rsp + 24]
	dec eax
	cmp dword ptr [rsp + 8], eax
	jl __find_antinodes_at_freq_loop_outer

	__find_antinodes_at_freq_loop_done:
	# long_array_free(&antinodes);
	lea rdi, [rsp + 16]
	call long_array_free

	add rsp, 48
	pop rbp
	ret

# void find_antinodes_for_antennas(Grid *antinodes, Coordinates antenna1, Coordinates antenna2);
find_antinodes_for_antennas:
	push rbp
	mov rbp, rsp
	sub rsp, 32

	# Move antinodes to stack at [rsp]
	mov qword ptr [rsp], rdi

	# Coordinates antinode1 = 2 * antenna1 - antenna2; // [rsp + 16]
	# Coordinates antinode2 = 2 * antenna2 - antenna1; // [rsp + 24]
	mov eax, esi
	add eax, eax
	sub eax, edx
	mov dword ptr [rsp + 16], eax

	mov eax, edx
	add eax, eax
	sub eax, esi
	mov dword ptr [rsp + 24], eax

	shr rsi, 32
	shr rdx, 32

	mov eax, esi
	add eax, eax
	sub eax, edx
	mov dword ptr [rsp + 20], eax

	mov eax, edx
	add eax, eax
	sub eax, esi
	mov dword ptr [rsp + 28], eax

	# grid_set(antinodes, antinode1.x, antinode1.y, '#');
	mov esi, dword ptr [rsp + 16]
	mov edx, dword ptr [rsp + 20]
	mov ecx, '#'
	call grid_set

	# grid_set(antinodes, antinode2.x, antinode2.y, '#');
	mov rdi, qword ptr [rsp]
	mov esi, dword ptr [rsp + 24]
	mov edx, dword ptr [rsp + 28]
	mov ecx, '#'
	call grid_set

	add rsp, 32
	pop rbp
	ret

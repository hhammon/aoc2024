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

	# Grid grid; // [rsp + 32]
	# grid_init(&grid, buf, len)
	lea rdi, [rsp + 32]
	mov rsi, qword ptr [rsp + 16]
	mov rdx, rax
	call grid_init

	# unsigned int guard_x; // [rsp + 48]
	# unsigned int guard_y; // [rsp + 52]
	# (guard_x, guard_y) = grid_search(&grid, '^');
	lea rdi, [rsp + 32]
	xor esi, esi
	mov sil, '^'
	call grid_search
	mov dword ptr [rsp + 48], eax
	mov dword ptr [rsp + 52], edx

	# unsigned int guard_move_x = 0; // [rsp + 56]
	# unsigned int guard_move_y = -1; // [rsp + 60]
	mov dword ptr [rsp + 56], 0
	mov dword ptr [rsp + 60], -1

	__main_loop:
	# grid_set(&grid, guard_x, guard_y, 'x');
	lea rdi, [rsp + 32]
	mov esi, dword ptr [rsp + 48]
	mov edx, dword ptr [rsp + 52]
	xor ecx, ecx
	mov cl, 'x'
	call grid_set

	# guard_x += guard_move_x;
	mov eax, dword ptr [rsp + 56]
	add dword ptr [rsp + 48], eax

	# guard_y += guard_move_y;
	mov eax, dword ptr [rsp + 60]
	add dword ptr [rsp + 52], eax

	# int map_item = grid_access(&grid, guard_x, guard_y);
	lea rdi, [rsp + 32]
	mov esi, dword ptr [rsp + 48]
	mov edx, dword ptr [rsp + 52]
	call grid_access # map_item can stay in eax

	# if (map_item < 0) break;
	cmp eax, 0
	jl __main_loop_done

	# if (map_item != '#') continue;
	cmp eax, '#'
	jne __main_loop

	# guard_x -= guard_move_x;
	mov eax, dword ptr [rsp + 56]
	sub dword ptr [rsp + 48], eax

	# guard_y -= guard_move_y;
	mov edx, dword ptr [rsp + 60]
	sub dword ptr [rsp + 52], edx

	# (guard_move_x, guard_move_y) = (-guard_move_y, guard_move_x);
	neg edx
	mov dword ptr [rsp + 56], edx
	mov dword ptr [rsp + 60], eax

	jmp __main_loop

	__main_loop_done:

	# unsigned int visited = grid_count(&grid, 'x');
	lea rdi, [rsp + 32]
	xor esi, esi
	mov sil, 'x'
	call grid_count

	# char visited_str[32]; // [rsp + 64]
	# int digits = uint_to_string(visited, visited_str)
	mov rdi, rax
	lea rsi, [rsp + 64]
	call uint_to_string

	# visited_str[digits] = '\n'
	mov byte ptr [rsp + rax + 64], '\n'

	# print(visited_str, digits) + 1;
	lea rdi, [rsp + 64]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 96
	pop rbp

	ret

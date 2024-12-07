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

	# char *map = alloc_mem(len); // [rsp + 24]
	mov rdi, rax
	call alloc_mem

	test rax, rax
	jz error

	mov qword ptr [rsp + 24], rax

	# mem_copy(map, buf, len);
	mov rdi, rax
	mov rsi, qword ptr [rsp + 16]
	mov rdx, qword ptr [rsp + 8]
	call mem_copy

	# Grid grid; // [rsp + 32]
	# grid_init(&grid, map, len)
	lea rdi, [rsp + 32]
	mov rsi, qword ptr [rsp + 24]
	mov rdx, qword ptr [rsp + 8]
	call grid_init

	# unsigned int obstacle_x; // [rsp + 56]
	# unsigned int obstacle_y = 0; // [rsp + 60]
	mov dword ptr [rsp + 60], 0

	# unsigned int looping_obstacles = 0; // [rsp + 64]
	mov dword ptr [rsp + 64], 0

	cmp dword ptr [rsp + 40], 0
	je __main_done

	cmp dword ptr [rsp + 44], 0
	je __main_done

	__main_loop_outer:
	# obstacle_x = 0
	mov dword ptr [rsp + 56], 0

	__main_loop_inner:
	# mem_copy(map, buf, len)
	mov rdi, qword ptr [rsp + 24]
	mov rsi, qword ptr [rsp + 16]
	mov rdx, qword ptr [rsp + 8]
	call mem_copy

	# if (grid_access(&grid, obstacle_x, obstacle_y) != '.') continue;
	lea rdi, [rsp + 32]
	mov esi, dword ptr [rsp + 56]
	mov edx, dword ptr [rsp + 60]
	call grid_access

	cmp eax, '.'
	jne __main_loop_continue

	# grid_set(&grid, obstacle_x, obstacle_y, '#');
	lea rdi, [rsp + 32]
	mov esi, dword ptr [rsp + 56]
	mov edx, dword ptr [rsp + 60]
	xor ecx, ecx
	mov cl, '#'
	call grid_set

	# looping_obstacles += check_for_loop(&grid)
	lea rdi, [rsp + 32]
	call check_for_loop
	add dword ptr [rsp + 64], eax

	__main_loop_continue:

	# obstacle_x++;
	mov eax, dword ptr [rsp + 40]
	inc dword ptr [rsp + 56]
	cmp dword ptr [rsp + 56], eax
	jl __main_loop_inner

	# obstacle_y++;
	mov eax, dword ptr [rsp + 44]
	inc dword ptr [rsp + 60]
	cmp dword ptr [rsp + 60], eax
	jl __main_loop_outer

	__main_done:

	# char looping_obstacles_str[32]; // [rsp + 72]
	# int digits = uint_to_string(looping_obstacles, looping_obstacles_str)
	mov edi, dword ptr [rsp + 64]
	lea rsi, [rsp + 72]
	call uint_to_string

	# looping_obstacles_str[digits] = '\n'
	mov byte ptr [rsp + rax + 72], '\n'

	# print(looping_obstacles_str, digits) + 1;
	lea rdi, [rsp + 72]
	mov esi, eax
	inc esi
	call print

	xor eax, eax

	add rsp, 112
	pop rbp

	ret

# bool check_for_loop(Grid *grid);
check_for_loop:
	push rbp
	mov rbp, rsp
	sub rsp, 32

	# grid moved to stack at [rsp + 24]
	mov qword ptr [rsp + 24], rdi

	# unsigned int guard_x; // [rsp]
	# unsigned int guard_y; // [rsp + 4]
	# (guard_x, guard_y) = grid_search(&grid, '^');
	mov sil, '^'
	call grid_search
	mov dword ptr [rsp], eax
	mov dword ptr [rsp + 4], edx

	# unsigned int guard_move_x = 0; // [rsp + 8]
	mov dword ptr [rsp + 8], 0

	# unsigned int guard_move_y = -1; // [rsp + 12]
	mov dword ptr [rsp + 12], -1

	# grid_set(grid, guard_x, guard_y, '.');
	mov rdi, qword ptr [rsp + 24]
	mov esi, eax
	mov edx, edx
	xor ecx, ecx
	mov cl, '.'
	call grid_set

	__check_for_loop_loop:
	# char dir_flag = MAGIC; // [rsp + 16]
	# ~'.' = 0b11010001
	# Because '#' < '.', we can do this.
	mov byte ptr [rsp + 16], 2
	mov ecx, dword ptr [rsp + 8]
	mov eax, dword ptr [rsp + 12]
	add ecx, ecx
	add eax, 3
	add ecx, eax
	cmp ecx, 4
	mov eax, 3
	cmove ecx, eax
	ror byte ptr [rsp + 16], cl

	# char *guard_addr = grid_elem_addr(grid, guard_x, guard_y)
	mov rdi, qword ptr [rsp + 24]
	mov esi, dword ptr [rsp]
	mov edx, dword ptr [rsp + 4]
	call grid_elem_addr

	# *guard_addr |= dir_flag;
	mov cl, byte ptr [rsp + 16]
	or byte ptr [rax], cl

	# guard_x += guard_move_x;
	mov eax, dword ptr [rsp + 8]
	add dword ptr [rsp + 0], eax

	# guard_y += guard_move_y;
	mov eax, dword ptr [rsp + 12]
	add dword ptr [rsp + 4], eax

	# int map_item = grid_access(grid, guard_x, guard_y);
	mov rdi, qword ptr [rsp + 24]
	mov esi, dword ptr [rsp]
	mov edx, dword ptr [rsp + 4]
	call grid_access # map_item can stay in eax

	# if (map_item < 0) return false;
	cmp eax, 0
	jge __check_for_loop_check

	mov rsp, rbp
	pop rbp

	xor eax, eax
	ret

	__check_for_loop_check:
	# if (map_item != '#')
	cmp eax, '#'
	je __check_for_loop_obstacle

	# if (map_item & dir_flag) return true;
	test al, byte ptr [rsp + 16]
	jz __check_for_loop_loop

	mov rsp, rbp
	pop rbp

	mov eax, 1
	ret

	# else

	__check_for_loop_obstacle:
	# guard_x -= guard_move_x;
	mov eax, dword ptr [rsp + 8]
	sub dword ptr [rsp], eax

	# guard_y -= guard_move_y;
	mov edx, dword ptr [rsp + 12]
	sub dword ptr [rsp + 4], edx

	# (guard_move_x, guard_move_y) = (-guard_move_y, guard_move_x);
	neg edx
	mov dword ptr [rsp + 8], edx
	mov dword ptr [rsp + 12], eax

	jmp __check_for_loop_loop

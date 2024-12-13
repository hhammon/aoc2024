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

	# LongArray trail_heads; // [rsp + 48]
	# grid_find_all(&map, &trail_heads, '0');
	lea rdi, [rsp + 32]
	lea rsi, [rsp + 48]
	mov edx, '0'
	call grid_find_all

	# unsigned int trail_count = 0; // [rsp + 24]
	mov dword ptr [rsp + 24], 0

	# int i = 0; // [rsp + 28]
	mov dword ptr [rsp + 28], 0

	__main_loop:
	mov ecx, dword ptr [rsp + 28]
	cmp ecx, dword ptr [rsp + 56]
	je __main_loop_done

	# count_trails(&map, trail_heads.ptr[i]);
	lea rdi, [rsp + 32]
	mov rsi, qword ptr [rsp + 48]
	mov rsi, qword ptr [rsi + 8 * rcx]
	call count_trails

	# trail_count += grid_count(&map, '#')
	lea rdi, [rsp + 32]
	mov esi, '#'
	call grid_count
	add dword ptr [rsp + 24], eax

	# grid_find_and_replace(&map, '#', '9')
	lea rdi, [rsp + 32]
	mov esi, '#'
	mov edx, '9'
	call grid_find_and_replace

	inc dword ptr [rsp + 28]
	jmp __main_loop

	__main_loop_done:

	# char sum_str[32]; // [rsp + 64]
	# int digits = uint_to_string(sum, sum_str)
	mov edi, dword ptr [rsp + 24]
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

# int count_trails(Grid *map, Coordinates coords);
count_trails:
	# int elevation = grid_access(map, coords.x, coords.y);
	push rdi
	push rsi

	mov rdx, rsi
	shr rdx, 32
	mov esi, esi
	call grid_access

	pop rsi
	pop rdi

	# if (elevation == -1) return 0;
	cmp eax, -1
	jne __count_trails_in_bounds

	xor eax, eax
	ret

	__count_trails_in_bounds:
	# if (elevation == '#') return 1;
	cmp eax, '#'
	jne __count_trails_not_found_dest

	mov eax, 1
	ret

	__count_trails_not_found_dest:
	# if (elevation == '9')
	cmp eax, '9'
	jne __count_trails_not_dest

	# grid_set(map, coords.x, coords.y, '#')
	mov rdx, rsi
	shr rdx, 32
	mov esi, esi
	mov ecx, '#'
	call grid_set

	# return 1;
	mov eax, 1
	ret

	__count_trails_not_dest:
	# int dir_flags = 0;
	# UP: 1
	# RIGHT: 2
	# DOWN: 4
	# LEFT: 8
	push rbx
	xor ebx, ebx

	# elevation++; // For comparison
	inc eax

	# int x = coords.x
	mov edx, esi

	# int y = coords.y
	mov rcx, rsi
	shr rcx, 32

	# dir_flags |= grid_access(map, x, y - 1) == elevation;
	push rax
	push rbx
	push rdi
	push rdx
	push rcx

	mov esi, edx
	mov edx, ecx
	dec edx
	call grid_access

	mov r8, rax
	
	pop rcx
	pop rdx
	pop rdi
	pop rbx
	pop rax

	xor esi, esi
	cmp r8, rax
	sete sil
	or ebx, esi

	# dir_flags |= (grid_access(map, x + 1, y) == elevation) << 1;
	push rax
	push rbx
	push rdi
	push rdx
	push rcx

	mov esi, edx
	mov edx, ecx
	inc esi
	call grid_access

	mov r8, rax
	
	pop rcx
	pop rdx
	pop rdi
	pop rbx
	pop rax

	xor esi, esi
	cmp r8, rax
	sete sil
	shl esi
	or ebx, esi

	# dir_flags |= (grid_access(map, x, y + 1) == elevation) << 2;
	push rax
	push rbx
	push rdi
	push rdx
	push rcx

	mov esi, edx
	mov edx, ecx
	inc edx
	call grid_access

	mov r8, rax
	
	pop rcx
	pop rdx
	pop rdi
	pop rbx
	pop rax

	xor esi, esi
	cmp r8, rax
	sete sil
	shl esi, 2
	or ebx, esi

	# dir_flags |= (grid_access(map, x - 1, y) == elevation) << 3;
	push rax
	push rbx
	push rdi
	push rdx
	push rcx

	mov esi, edx
	mov edx, ecx
	dec esi
	call grid_access

	mov r8, rax
	
	pop rcx
	pop rdx
	pop rdi
	pop rbx
	pop rax

	xor esi, esi
	cmp r8, rax
	sete sil
	shl esi, 3
	or ebx, esi

	# int count = 0;
	xor eax, eax

	# if (dir_flags & UP) count = count_trails(map, (Coordinates) {.x = x, .y = y - 1});
	test ebx, 1
	jz __count_trails_right

	push rdi
	push rdx
	push rcx
	push rbx

	dec ecx
	mov esi, ecx
	shl rsi, 32
	or rsi, rdx
	call count_trails

	pop rbx
	pop rcx
	pop rdx
	pop rdi

	__count_trails_right:
	test ebx, 2
	jz __count_trails_down

	# if (dir_flags & RIGHT) count += count_trails(map, (Coordinates) {.x = x + 1, .y = y});
	push rax
	push rdi
	push rdx
	push rcx
	push rbx

	inc edx
	mov esi, ecx
	shl rsi, 32
	or rsi, rdx
	call count_trails

	pop rbx
	pop rcx
	pop rdx
	pop rdi
	mov esi, eax
	pop rax
	
	add eax, esi

	__count_trails_down:
	test ebx, 4
	jz __count_trails_left

	# if (dir_flags & DOWN) count += count_trails(map, (Coordinates) {.x = x, .y = y + 1});
	push rax
	push rdi
	push rdx
	push rcx
	push rbx

	inc ecx
	mov esi, ecx
	shl rsi, 32
	or rsi, rdx
	call count_trails

	pop rbx
	pop rcx
	pop rdx
	pop rdi
	mov esi, eax
	pop rax
	
	add eax, esi
	
	__count_trails_left:
	test ebx, 8
	jz __count_trails_return

	# if (dir_flags & LEFT) count += count_trails(map, (Coordinates) {.x = x - 1, .y = y});
	push rax
	push rdi
	push rdx
	push rcx
	push rbx

	dec edx
	mov esi, ecx
	shl rsi, 32
	or rsi, rdx
	call count_trails

	pop rbx
	pop rcx
	pop rdx
	pop rdi
	mov esi, eax
	pop rax
	
	add eax, esi

	__count_trails_return:	
	# return count;
	pop rbx
	ret

.intel_syntax noprefix

.global grid_init
.global grid_access
.global grid_set
.global grid_search
.global grid_count
.global grid_elem_addr
.global grid_find_all
.global grid_find_and_replace

.section .text

# struct Grid {
#     unsigned char *data; // bytes 0-7
#     unsigned int width; // bytes 8-11
#     unsigned int height; // bytes 12-15
# }
#
# sizeof Grid = 16
# This struct should always be quadword aligned,
# if not double-quadword aligned.
# This is intended to source data directly from a text file
# with `height` lines and `width` + 1 characters in each line
# including the line feed at the end (except the last line)
# The last line should not have a line feed, and so the total
# length of the data should be (`width` + 1) * `height` - 1

# void grid_init(Grid *grid, char *data, unsigned long data_len);
grid_init:
	# store data in grid
	mov qword ptr [rdi], rsi

	# determine width by counting until first line feed.
	# unsigned int width = 0;
	xor ecx, ecx

	__grid_init_width_loop:
	cmp ecx, edx
	je __grid_init_width_loop_done

	cmp byte ptr [rsi + rcx], '\n'
	je __grid_init_width_loop_done
	
	inc ecx
	jmp __grid_init_width_loop

	__grid_init_width_loop_done:
	mov dword ptr [rdi + 8], ecx

	# unsigned int height = (data_len + 1) / (width + 1);
	mov r8, rdx
	mov rax, rdx
	inc rax
	xor edx, edx
	inc rcx
	div rcx
	mov rdx, r8
	mov dword ptr [rdi + 12], eax

	ret

# int grid_access(Grid *grid, int x, int y);
# Each element is actually a char, but this is an int so
# it can return -1 for out of bounds.
grid_access:
	cmp esi, 0
	jl __grid_access_oob

	cmp esi, dword ptr [rdi + 8]
	jge __grid_access_oob

	cmp edx, 0
	jl __grid_access_oob

	cmp edx, dword ptr [rdi + 12]
	jge __grid_access_oob

	# int idx = x + (grid->width + 1) * y
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul edx
	add esi, eax

	# return grid->data[idx];
	mov rdi, qword ptr [rdi]
	xor eax, eax
	mov al, byte ptr [rdi + rsi]
	ret

	__grid_access_oob:
	mov eax, -1
	ret

# bool grid_set(Grid* grid, int x, y, unsigned char item);
# Attempts a set and returns true if possible. Return false if out of bounds;
grid_set:
	cmp esi, 0
	jl __grid_set_oob

	cmp esi, dword ptr [rdi + 8]
	jge __grid_set_oob

	cmp edx, 0
	jl __grid_set_oob

	cmp edx, dword ptr [rdi + 12]
	jge __grid_set_oob

	# int idx = x + (grid->width + 1) * y
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul edx
	add esi, eax

	# grid->data[idx] = item;
	mov rdi, [rdi]
	mov byte ptr [rdi + rsi], cl

	mov eax, 1
	ret

	__grid_set_oob:
	xor eax, eax
	ret

# (unsigned int, unsigned int) grid_search(Grid *grid, unsigned char item);
# Searches the grid for the first occurence (left-to-right then top-to-bottom)
# and return the coordinates (x, y) in (eax, edx)
grid_search:
	# unsigned int len = (grid->width + 1) * grid->height - 1;
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul dword ptr [rdi + 12]
	dec eax
	
	# Move variables around
	mov edx, eax # edx now contains len

	xor eax, eax
	mov al, sil # al now contains item (needed here for string op)

	mov esi, dword ptr [rdi + 8] # esi now contains grid->width

	mov rdi, qword ptr [rdi] # rdi now contains grid->data (needed here for string op)

	# Search string
	cld
	mov rcx, rdx
	repnz scasb

	mov r8, rcx
	mov rcx, rdx
	sub rcx, r8
	dec rcx # rcx now contains the index of item (idx)

	# return (idx % (grid->width + 1), idx / (grid->width + 1))
	inc esi
	mov eax, ecx
	xor edx, edx
	div esi
	xchg eax, edx
	ret

# unsigned int grid_count(Grid *grid, unsigned char item);
grid_count:
	# unsigned int len = (grid->width + 1) * grid->height - 1;
	xor edx, edx
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul dword ptr [rdi + 12]
	dec eax
	mov edx, eax

	# int total = 0;
	xor eax, eax

	# int i = 0;
	xor ecx, ecx

	# grid->data
	mov rdi, qword ptr [rdi]

	xor r8, r8 # Used as boolean


	test edx, edx
	jnz __grid_count_loop

	ret

	__grid_count_loop:
	cmp byte ptr [rdi + rcx], sil
	sete r8b
	add eax, r8d

	inc ecx
	cmp ecx, edx
	jl __grid_count_loop
	
	ret

# char *grid_elem_addr(Grid *grid, unsigned int x, unsigned int y);
grid_elem_addr:
	# return grid->data + x + (grid->width + 1) * y
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul edx
	add eax, esi
	add rax, qword ptr [rdi]
	ret

# struct Coordinates {
#     int x; // bytes 0-3
#     int y; // bytes 4-7
# }

# sizeof Coordinates = 8
# This struct should always be quadword aligned.
# For simplicity, we'll represent point-wise arithmetic operations on the struct itself.

# void grid_find_all(Grid *grid, LongArray *coords, char item);
# We can use our LongArray for coords because the element size is the same.
grid_find_all:
	# long_array_init(coords, 512);
	push rdi
	push rsi
	push rdx

	mov rdi, rsi
	mov esi, 512
	call long_array_init

	pop rdx
	pop rsi
	pop rdi

	mov r10b, dl # temp

	# unsigned int len = (grid->width + 1) * grid->height - 1;
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul dword ptr [rdi + 12]
	dec eax
	
	# Move variables around
	mov edx, eax # edx now contains len

	xor eax, eax
	mov al, r10b # al now contains item (needed here for string op)

	mov r10d, dword ptr [rdi + 8] # r10d now contains grid->width

	mov rdi, qword ptr [rdi] # rdi now contains grid->data (needed here for string op)

	mov ecx, edx

	# Search string repeatedly until rcx hits 0
	# There will be one more search than instances of item, so do one first.
	cld
	repnz scasb

	__grid_find_all_loop:
	test ecx, ecx
	jz __grid_find_all_loop_done

	mov r8, rdx
	sub r8, rcx
	dec r8 # r8 now contains the index of item (idx)

	# (x, y) = (idx % (grid->width + 1), idx / (grid->width + 1))
	inc r10d
	xchg rax, r8
	xor r9, r9
	xchg rdx, r9
	div r10d
	dec r10d

	# long_array_push(coords, (y << 32) | x)
	push r8
	push r9
	push rdi
	push rsi
	push rcx
	push r10

	mov rdi, rsi
	mov rsi, rax
	shl rsi, 32
	or rsi, rdx
	call long_array_push

	# pops to rdx and rax to undo xchg operations from before.
	pop r10
	pop rcx
	pop rsi
	pop rdi
	pop rdx
	pop rax

	# search for next occurence
	repnz scasb

	jmp __grid_find_all_loop

	__grid_find_all_loop_done:
	ret

# void grid_find_and_replace(Grid *grid, char f, char r);
grid_find_and_replace:
	# Move r to r8 for mul instruction
	mov r8, rdx

	# unsigned int len = (grid->width + 1) * grid->height - 1;
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul dword ptr [rdi + 12]
	dec eax
	
	# Move variables around
	mov ecx, eax # edx now contains len

	xor eax, eax
	mov al, sil # al now contains item (needed here for string op)

	mov rdi, qword ptr [rdi] # rdi now contains grid->data (needed here for string op)

	# Search string repeatedly until rcx hits 0
	# There will be one more search than instances of item, so do one first.
	cld
	repnz scasb

	__grid_find_and_replace_loop:
	test ecx, ecx
	jz __grid_find_and_replace_loop_done

	# rdi now points to the byte after the occurence found
	mov byte ptr [rdi - 1], r8b

	# search for next occurence
	repnz scasb

	jmp __grid_find_and_replace_loop

	__grid_find_and_replace_loop_done:
	ret

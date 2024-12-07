.intel_syntax noprefix

.global grid_init
.global grid_access
.global grid_set
.global grid_search
.global grid_count
.global grid_elem_addr

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

# void grid_set(Grid* grid, unsigned int x, unsigned y, unsigned char item);
grid_set:
	# int idx = x + (grid->width + 1) * y
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul edx
	add esi, eax

	# grid->data[idx] = item;
	mov rdi, [rdi]
	mov byte ptr [rdi + rsi], cl

	ret

# (unsigned int, unsigned int) grid_search(Grid *grid, unsigned char item);
# Searches the grid for the first occurence (left-to-right then top-to-bottom)
# and return the coordinates (x, y) in (eax, edx)
grid_search:
	# unsigned int len = (grid->width + 1) * grid->height - 1;
	xor edx, edx
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

# char *grid_elem_addr(&grid, unsigned int x, unsigned int y);
grid_elem_addr:
	# return grid->data + x + (grid->width + 1) * y
	mov eax, dword ptr [rdi + 8]
	inc eax
	mul edx
	add eax, esi
	add rax, qword ptr [rdi]
	ret

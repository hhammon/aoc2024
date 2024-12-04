.intel_syntax noprefix

.global count_word

.section .text

# unsigned int count_word(char *word, char *word_search, unsigned int len);
# Returns number of occurrences of word in word_search 
count_word:
	# (width, height) = get_dimensions(word_search, len)
	push rdi
	push rsi

	mov rdi, rsi
	mov rsi, rdx
	call get_dimensions

	mov rcx, rdx
	mov rdx, rax

	pop rsi
	pop rdi

	# unsigned int count = 0
	xor eax, eax

	# int x = 0
	xor r8, r8

	__count_word_loop_outer:
	cmp r8, rdx
	jge __count_word_loop_outer_done

	# int y = 0
	xor r9, r9

	__count_word_loop_inner:
	cmp r9, rcx
	jge __count_word_loop_inner_done

	# count += count_word_from_coords(word, word_search, width, height, x, y);
	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9
	push rax

	call count_word_from_coords

	mov edx, eax
	pop rax
	add rax, rdx

	pop r9
	pop r8
	pop rcx
	pop rdx
	pop rsi
	pop rdi

	inc r9
	jmp __count_word_loop_inner

	__count_word_loop_inner_done:
	inc r8
	jmp __count_word_loop_outer

	__count_word_loop_outer_done:
	ret

# unsigned int count_word_from_coords(
#     char *word,
#     char *word_search, 
#     unsigned int width,
#     unsigned int height,
#     unsigned int x,
#     unsigned int y
# );
count_word_from_coords:
	push r12

	# unsigned int count = 0;
	xor eax, eax

	# int i = -1
	mov r10, -1

	__count_word_from_coords_loop_outer:
	cmp r10, 1
	jg __count_word_from_coords_loop_outer_done

	# int j = -1
	mov r11, -1

	__count_word_from_coords_loop_inner:
	cmp r11, 1
	jg __count_word_from_coords_loop_inner_done

	# if (i == 0 && j == 0) contine;
	mov r12, r10
	or r12, r11
	jz __count_word_from_coords_loop_inner_continue

	# count += check_word_from_coords_in_dir(
	#    word,
	#    word_search,
	#    width,
	#    height,
	#    x,
	#    y,
	#    i,
	#    j
	# )

	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9
	push r10
	push r11
	push rax

	push r11
	push r10
	call check_word_from_coords_in_dir

	add rsp, 16

	mov edx, eax
	pop rax
	add rax, rdx

	pop r11
	pop r12
	pop r9
	pop r8
	pop rcx
	pop rdx
	pop rsi
	pop rdi

	__count_word_from_coords_loop_inner_continue:
	inc r11
	jmp __count_word_from_coords_loop_inner

	__count_word_from_coords_loop_inner_done:
	inc r10
	jmp __count_word_from_coords_loop_outer

	__count_word_from_coords_loop_outer_done:
	pop r12

	ret

# bool check_word_from_coords_in_dir(
#     char *word,
#     char *word_search, 
#     unsigned int width,
#     unsigned int height,
#     unsigned int x,
#     unsigned int y
#     unsigned int x_dir
#     unsigned int y_dir
# );
check_word_from_coords_in_dir:
	# Move x_dir and y_dir into r10, r11 respectively
	mov r10, qword ptr [rsp + 8]
	mov r11, qword ptr [rsp + 16]
	
	push rbx
	push r12
	push r13
	
	# int i = 0
	xor ebx, ebx

	# char c = 0
	xor r12, r12

	# while (c = word[i]) != '\0'
	__check_word_from_coords_in_dir_loop:
	# ret_val = true;
	mov eax, 1

	mov r12b, byte ptr [rdi + rbx]
	test r12, r12
	jz __check_word_from_coords_in_dir_loop_done
	
	# ret_val = false; // In case of early return
	xor eax, eax

	# if (x < 0 || y < 0 || x >= width || y >= height) return false;

	cmp r8, 0
	jl __check_word_from_coords_in_dir_loop_done

	cmp r9, 0
	jl __check_word_from_coords_in_dir_loop_done

	cmp r8, rdx
	jge __check_word_from_coords_in_dir_loop_done

	cmp r9, rcx
	jge __check_word_from_coords_in_dir_loop_done

	# unsigned int idx = y * width + x
	mov r13, rdx
	mov rax, r9
	mul rdx
	add rax, r8
	mov rdx, r13
	mov r13, rax
	xor eax, eax

	# if (word_search[idx] != c) return false;
	cmp r12b, byte ptr [rsi + r13]
	jne __check_word_from_coords_in_dir_loop_done

	# i++;
	inc ebx

	# x += x_dir;
	add r8, r10

	# y += y_dir;
	add r9, r11

	jmp __check_word_from_coords_in_dir_loop

	__check_word_from_coords_in_dir_loop_done:

	pop r13
	pop r12
	pop rbx

	ret

# (unsigned int, unsigned int) get_dimensions(char *word_search, unsigned int len);
# Returns (width, height) in (rax, rdx). New line characters will be counted in width for
# simplicity in other calculations.
get_dimensions:
	# int i = 0
	xor ecx, ecx

	xor edx, edx

	__get_dimensions_loop:
	cmp ecx, esi
	je __get_dimensions_loop_done
	
	# char c = word_search[i]
	mov dl, byte ptr [rdi + rcx]

	# i++;
	inc ecx
	
	# if (c == '\n') break;
	cmp dl, '\n'
	jne __get_dimensions_loop

	__get_dimensions_loop_done:

	# return (i, (len + 1) / i); // Add 1 to len because last line will not have a new line
	xor edx, edx
	mov eax, esi
	inc eax
	div ecx
	mov edx, eax

	mov eax, ecx

	ret

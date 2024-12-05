.intel_syntax noprefix

.global rule_set_init
.global is_rule
.global fill_rule_set

.section .text

# struct RuleSet {
#     bool *rules; // bytes 0-7
#     unsigned int page_low //bytes 8-11
#     unsigned int num_pages // bytes 12-15
# }
#
# sizeof RuleSet = 16
# This struct should always be quadword aligned
# if not double-quadword aligned.
#
# `page_low` and `num_pages` indicate the range of page
# numbers included in the RuleSet, including `range_low`,
# up to, but excluding, `page_low + num_pages`.
# `rules` is a `num_pages` x `num_pages` array of bools (bytes)
# such that `rules[i][j] == true` indicates that
# (page_low + i)|(page_low + j) is a rule.

# void rule_set_init(RuleSet *rule_set, unsigned int page_low, unsigned int num_pages);
rule_set_init:
	# Move params into rule_set
	mov dword ptr [rdi + 8], esi
	mov dword ptr [rdi + 12], edx

	# Allocate num_pages * num_pages bytes
	mov eax, edx
	mul eax

	push rdi

	mov edi, eax
	call alloc_mem

	test eax, eax
	jz error

	pop rdi

	mov qword ptr [rdi], rax

	# No need to zero memory since it came directly from the OS
	ret

# bool is_rule(RuleSet *rule_set, unsigned int page1, unsigned int page2);
is_rule:
	# adjust pages to be indices
	sub esi, dword ptr [rdi + 8]
	sub edx, dword ptr [rdi + 8]

	# rule_set->num_pages
	mov ecx, dword ptr [rdi + 12]

	# return false if either index is out of bounds.
	cmp esi, 0
	jl __is_rule_return_false

	cmp edx, 0
	jl __is_rule_return_false

	cmp esi, ecx
	jge __is_rule_return_false

	cmp edx, ecx
	jge __is_rule_return_false

	# return rule_set->rules[page1 * rule_set->num_pages + page2]
	mov r8d, edx
	mov eax, esi
	mul ecx
	add eax, r8d
	mov ecx, eax
	xor eax, eax
	mov rdi, qword ptr [rdi]
	mov al, byte ptr [rdi + rcx]
	ret

	__is_rule_return_false:
	xor eax, eax
	ret

# (unsigned int, unsigned int)
# fill_rule_set(IntArray *pages, IntArray *lengths, RuleSet *rule_set);
# Returns (pages_idx, lengths_idx) to the fisrt "update" in (eax, edx)
fill_rule_set:
	# All entries are rules until the first occurence of the length being 0
	# First, loop through and find the range of page numbers to init rule_set

	push rbx

	# unsigned int min_page = INT_MAX;
	mov eax, -1

	# unsigned int max_page = 0
	xor ecx, ecx

	# int i = 0;
	xor r8, r8

	# lengths->len
	mov r9d, dword ptr [rdi + 8]

	# pages->ptr
	mov r10, qword ptr [rdi]

	# lengths->ptr
	mov r11, qword ptr [rsi]

	__fill_rule_set_loop1:
	# if (lengths->ptr[i] == 0) break;
	cmp dword ptr [r11 + 4 * r8], 0
	je __fill_rule_set_loop1_done

	# i *= 2
	add r8, r8

	# unsigned int page = pages->ptr[i]
	mov ebx, dword ptr [r10 + 4 * r8]

	# if (page < min_page) min_page = page;
	cmp ebx, eax
	cmovb eax, ebx

	# if (page > max_page) max_page = page;
	cmp ebx, ecx
	cmova ecx, ebx

	# i++;
	inc r8

	# page = pages->ptr[i]
	mov ebx, dword ptr [r10 + 4 * r8]

	# if (page < min_page) min_page = page;
	cmp ebx, eax
	cmovb eax, ebx

	# if (page > max_page) max_page = page;
	cmp ebx, ecx
	cmova ecx, ebx

	# i = i / 2 + 1
	shr r8
	inc r8
	
	cmp r8, r9
	jle __fill_rule_set_loop1

	__fill_rule_set_loop1_done:

	cmp eax, ecx
	jbe __fill_rule_set_init

	# *rule_set = {0};
	mov qword ptr [rdx], 0
	mov qword ptr [rdx + 8], 0
	ret

	__fill_rule_set_init:
	# rule_set_init(rule_set, min_page, max_page - min_page + 1);
	sub ecx, eax
	inc ecx

	push rdi
	push rsi
	push rdx

	mov rdi, rdx
	mov esi, eax
	mov edx, ecx
	call rule_set_init

	pop rdx
	pop rsi
	pop rdi

	# int i = 0;
	xor r8, r8

	# lengths->len
	mov r9d, dword ptr [rdi + 8]

	# pages->ptr
	mov r10, qword ptr [rdi]

	# lengths->ptr
	mov r11, qword ptr [rsi]

	# unsigned int lengths_idx = 0
	xor ecx, ecx

	__fill_rule_set_loop2:
	# if (lengths->ptr[i] == 0) break;
	cmp dword ptr [r11 + 4 * r8], 0
	je __fill_rule_set_loop2_done

	add ecx, dword ptr [r11 + 4 * r8]

	# i *= 2
	add r8, r8

	# unsigned int page1 = pages->ptr[i];
	mov eax, dword ptr [r10 + 4 * r8]

	# i++;
	inc r8

	# unsigned int page2 = pages->ptr[i];
	mov ebx, dword ptr [r10 + 4 * r8]

	push rax
	push rbx
	push rdx
	push rdi

	# Convert pages to indices
	sub eax, dword ptr [rdx + 8]
	sub ebx, dword ptr [rdx + 8]

	# rule_set->rules[page1 * rule_set->num_pages + page2] = true;
	mov rdi, qword ptr [rdx]
	mul dword ptr [rdx + 12]
	add eax, ebx
	mov byte ptr [rdi + rax], 1

	pop rdi
	pop rdx
	pop rbx
	pop rax

	# i = i / 2 + 1
	shr r8
	inc r8
	
	cmp r8, r9
	jle __fill_rule_set_loop2

	__fill_rule_set_loop2_done:

	pop rbx

	mov eax, ecx
	mov edx, r8d
	inc edx

	ret

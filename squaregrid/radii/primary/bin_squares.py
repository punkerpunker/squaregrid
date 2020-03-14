def bin_to_our(square_id):
	square_id -= 1
	r = int(square_id ** 0.5 + 1e-8) // 2
	num = square_id - (2 * r) ** 2
	l = r + 1
	# if num <= 2 * l - 1:
	#   num = 2 * l - 1 - num + (4 * l - 2)
	# elif num <= 4 * l - 2:
	#   num = 4 * l - 2 - num + (2 * l - 1)
	if num <= 6 * l - 3:
		num = 6 * l - 3 - num
	elif num <= 8 * l - 5:
		num = 8 * l - 5 - num + (6 * l - 2)
	else:
		assert(False)
	return (2 * r) ** 2 + num

def our_to_bin(square_id):
	r = int(square_id ** 0.5 + 1e-8) // 2
	num = square_id - (2 * r) ** 2
	l = r + 1
	# if num <= 2 * l - 1:
	#   num = 2 * l - 1 - num + (4 * l - 2)
	# elif num <= 4 * l - 2:
	#   num = 4 * l - 2 - num + (2 * l - 1)
	if num <= 6 * l - 3:
		num = 6 * l - 3 - num
	elif num <= 8 * l - 5:
		num = 8 * l - 5 - num + (6 * l - 2)
	else:
		assert(False)
	return (2 * r) ** 2 + num + 1

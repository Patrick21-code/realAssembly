#Doodle Jump Clone
#Name: ....

#Controls:
#'a' = left
#'d' = right
#'s' = retry

.data
	score_text_color: .word 0x000000	# Black color for score text
	platform_array: .space 16			# Array to store platform positions (4 platforms * 4 bytes each)
	white_color: .word 0xFFFFFF	 # White color value for background
	black_platform_color: .word 0x000000		 # Black color for platforms
	black_sprite_color: .word 0x000000		 # Black color for sprite 
	lava_line_color: .word 0xFFFFFF		 # Color for lava/game over line
	black_sprite_color2: .word 0x000000		# Secondary black color for sprite
	pure_black: .word 0x000000			# Pure black color value
	display_base_address: .word 0x10008000    # Base address for bitmap display
		 
.text

main:
	lw $t0, display_base_address	# Load display base address into $t0 
	la $t1, platform_array # Load address of platform array into $t1
	jal fill_background_white  # Call function to color background white
	jal initialize_starting_platforms # Call function to create initial platforms
	
	lw $t2, 12($t1) # Load location of bottom platform for sprite positioning
	addi $t2, $t2, -496 # Position sprite 3 pixels above middle of lowest platform
	jal render_player_sprite # Call function to draw the player sprite
	
	li $t3, 0 # Initialize jump counter (0-17: jump up, 18+: fall down)
	li $t4, 0 # Initialize score counter (increments when new platform created)
	li $t5, 5 # Initialize difficulty level (affects platform width)
	# Difficulty increases every 10 points scored
	li $t6, 1 # Helper variable for score-based difficulty progression
	
game_main_loop:
	jal handle_keyboard_input  	# Check for player input (A/D keys)
	
	beq $t3, 18, player_falls_down	# If jump counter reaches 18, start falling

player_jumps_up:
	addi $t2, $t2, -128 # Move sprite up one row (128 pixels = 32 * 4 bytes per pixel)
	addi $t3, $t3, 1 # Increment jump counter
	j continue_main_loop # Skip falling logic
	
player_falls_down: # Handle sprite falling down
	addi $t2, $t2, 128 # Move sprite down one row
	jal check_lava_death # Check if sprite fell into lava (game over condition)
	jal detect_platform_collision # Check if sprite landed on a platform

continue_main_loop:
	jal check_screen_scroll # Check if screen needs to scroll up
	
redraw_game_screen:
	jal fill_background_white # Clear screen with white background
	
	jal calculate_and_display_score # Update difficulty and prepare score display
	
	# Determine number of digits and center position
	li $s0, 0 # Initialize screen position for score
	bne $s3, 0, display_three_digits # If hundreds digit != 0, display 3 digits
	bne $s4, 0, display_two_digits   # If tens digit != 0, display 2 digits
	
display_one_digit:
	addi $s0, $t0, 60  # Center position for 1 digit (middle of 32-pixel width)
	move $s6, $s5 # Move ones digit to display register
	jal render_score_digit # Draw ones digit
	j score_display_complete
	
display_two_digits:
	addi $s0, $t0, 52  # Center position for 2 digits
	move $s6, $s4 # Move tens digit to display register
	jal render_score_digit # Draw tens digit
	addi $s0, $s0, 16 # Move to next digit position
	move $s6, $s5 # Move ones digit to display register
	jal render_score_digit # Draw ones digit
	j score_display_complete
	
display_three_digits:
	addi $s0, $t0, 44  # Center position for 3 digits
	move $s6, $s3 # Move hundreds digit to display register
	jal render_score_digit # Draw hundreds digit
	addi $s0, $s0, 16 # Move to next digit position
	move $s6, $s4 # Move tens digit to display register
	jal render_score_digit # Draw tens digit
	addi $s0, $s0, 16 # Move to next digit position
	move $s6, $s5 # Move ones digit to display register
	jal render_score_digit # Draw ones digit
	
score_display_complete:
	jal render_all_platforms # Draw all platforms on screen
	jal render_player_sprite # Draw player sprite
	
	j game_main_loop # Return to main game loop
	
handle_keyboard_input:
	li $v0, 32 # System call for sleep
	li $a0, 50 # Sleep for 50 milliseconds (game timing)
	syscall # Execute sleep
	lw $s0, 0xffff0000 # Load keyboard control register
	beq $s0, 1, process_key_press # If key is pressed, process it
	jr $ra # Return if no input detected
	
process_key_press:
	lw $s1, 0xffff0004 # Load the actual key value from keyboard data register
	beq $s1, 97, move_sprite_left # If key is 'a' (ASCII 97), move left
	beq $s1, 100, move_sprite_right # If key is 'd' (ASCII 100), move right
	jr $ra # Return if key is not A or D
	
move_sprite_left:
	addi $t2, $t2, -4 # Move sprite one pixel to the left (4 bytes per pixel)
	jr $ra # Return to caller

move_sprite_right:
	addi $t2, $t2, 4 # Move sprite one pixel to the right (4 bytes per pixel)
	jr $ra # Return to caller

check_lava_death: # Check if sprite fell below screen (into lava)
	li $s0, 0 # Initialize comparison value
	addi $s0, $t0, 4096 # Calculate bottom-right pixel location (32*32*4 = 4096)
	# If sprite location is below screen bottom, trigger game over
	bgt $t2, $s0, trigger_game_over # Branch to game over if sprite fell too far
	jr $ra # Return if sprite is still on screen
	
trigger_game_over:
	j end_game_sequence # Jump to game over sequence
	
detect_platform_collision:
	li $s0, 0 # Initialize loop counter for checking platforms
	li $s1, 4 # Set maximum number of platforms to check
	la $s2, 0($t1) # Load base address of platform array

platform_collision_loop:
	beq $s0, $s1, platform_collision_end # Exit loop when all platforms checked
	lw $s3, 0($s2) # Load current platform position
	li $s4, 0 # Initialize leftmost collision boundary
	li $s5, 0 # Initialize rightmost collision boundary
	li $s6, 8 # Base value for calculating platform width based on difficulty
	sub $s6, $s6, $t5 # Adjust width based on difficulty (harder = narrower platforms)
	mul $s6, $s6, 4 # Convert to pixel offset (4 bytes per pixel)
	addi $s4, $s3, -260 # Set left collision boundary (accounting for sprite width)
	addi $s5, $s3, -220 # Set base right collision boundary
	sub $s5, $s5, $s6 # Adjust right boundary based on difficulty
	bge $t2, $s4, check_right_boundary # If sprite is past left boundary, check right

continue_collision_check:
	addi $s0, $s0, 1 # Increment platform counter
	addi $s2, $s2, 4 # Move to next platform in array
	j platform_collision_loop # Continue checking next platform
	
check_right_boundary:
	bgt $t2, $s5, continue_collision_check # If sprite is past right boundary, continue
	li $t3, 0 # Reset jump counter (sprite landed on platform, can jump again)

platform_collision_end:
	jr $ra # Return to caller
	
check_screen_scroll:
	li $s0, 0 # Initialize screen boundary check
	addi $s0, $t0, 896 # Calculate scroll trigger position (7 rows from top)
	blt $t2, $s0, scroll_screen_up # If sprite is in upper portion, scroll screen
	jr $ra # Return if no scrolling needed

scroll_screen_up:
	li $s0, 0 # Initialize variables for platform manipulation
	la $s2, 0($t1) # Load platform array base address
	addi $s0, $s2, 12 # Point to bottom platform (index 3)
	add $s4, $t0, 3968 # Calculate last row position on screen
	lw $s3, 0($s0) # Load bottom platform position
	addi $t2, $t2, 128 # Move sprite down one row to compensate for scroll
	bge $s3, $s4, create_new_platform # If bottom platform reached edge, create new one

move_platforms_down:
	li $s5, 0 # Initialize loop counter for moving platforms
	li $s6, 16 # Set loop limit (4 platforms * 4 bytes = 16)
	li $s4, 0 # Initialize working register

platform_move_loop:
	beq $s5, $s6, platform_move_complete # Exit when all platforms moved
	la $s7, 0($t1) # Load platform array base address
	add $s4, $s7, $s5 # Calculate current platform address
	lw $s3, 0($s4) # Load current platform position
	addi $s3, $s3, 128 # Move platform down one row
	sw $s3, 0($s4) # Store updated platform position
	addi $s5, $s5, 4 # Move to next platform (4 bytes per address)
	j platform_move_loop # Continue with next platform
	
platform_move_complete:
	jr $ra # Return to caller

create_new_platform:
	li $v0, 42 # System call for random number generation
	li $a1, 32 # Set upper bound for random number (0-31)
	sub $a1, $a1, $t5 # Adjust range based on difficulty
	syscall # Generate random number (result in $a0)
	
	# Convert random number to pixel position
	li $s1, 4 # Multiplier for pixel positioning (4 bytes per pixel)
	mul $s1, $s1, $a0 # Calculate pixel offset from random number
	add $s1, $t0, $s1  # Calculate absolute position for new platform
	addi $s1, $s1, -128 # Position new platform one row above screen top
	
	addi $t4, $t4, 1 # Increment score (new platform created)
	
	# Shift existing platforms down in array to make room for new one
	li $s5, 12 # Start from second-to-last platform (index 3->2->1->0)
	li $s6, 0 # End condition for shifting loop
	li $s4, 0 # Working register for array manipulation

shift_platform_array:
	beq $s5, $s6, shift_complete # Exit when shifting complete
	la $s7, 0($t1) # Load platform array base address
	add $s4, $s7, $s5 # Calculate current platform position in array
	lw $s0, -4($s4) # Load previous platform position
	sw $s0, 0($s4) # Store at current position (shift down)
	addi $s5, $s5, -4 # Move to previous platform
	j shift_platform_array # Continue shifting

shift_complete:
	li $s4, 0 # Reset working register
	la $s7, 0($t1) # Load platform array base address
	addi $s4, $s7, 0 # Point to first array position
	sw $s1, 0($s4) # Store new platform at top of array (index 0)
	j move_platforms_down # Continue with moving all platforms down

############################## DRAWING FUNCTIONS ##########################
# Function to fill background with white color and add lava line at bottom:
fill_background_white:
	add $s0, $t0, $zero # Set starting position to display base address
	li $s1, 0 # Initialize pixel counter
	li $s2, 960 # Set counter for white area (30 rows * 32 pixels)
	li $s4, 1024 # Set total pixel count (32 * 32 = 1024)

white_background_loop:
	beq $s1, $s2, draw_lava_line # When white area complete, draw lava line
	lw $s3, white_color # Load white color value
	sw $s3, 0($s0) # Paint current pixel white
	addi $s0, $s0, 4 # Move to next pixel (4 bytes per pixel)
	addi $s1, $s1, 1 # Increment pixel counter
	j white_background_loop # Continue painting white
draw_lava_line:
	beq $s1, $s4, background_complete # Exit when entire screen painted
	lw $s5, lava_line_color # Load lava line color
	sw $s5, 0($s0) # Paint current pixel with lava color
	addi $s0, $s0, 4 # Move to next pixel
	addi $s1, $s1, 1 # Increment pixel counter
	j draw_lava_line # Continue painting lava line

background_complete:
	jr $ra # Return to caller
	
fill_background_game_over:
	add $s0, $t0, $zero # Set starting position to display base address
	li $s1, 0 # Initialize pixel counter
	li $s2, 1024 # Set total pixel count for entire screen

game_over_background_loop:
	beq $s1, $s2, game_over_background_complete # Exit when screen filled
	lw $s3, lava_line_color # Load game over background color
	sw $s3, 0($s0) # Paint current pixel
	addi $s0, $s0, 4 # Move to next pixel
	addi $s1, $s1, 1 # Increment pixel counter
	j game_over_background_loop # Continue filling screen

game_over_background_complete:
	jr $ra # Return to caller

initialize_starting_platforms:
	li $s0, 0 # Initialize platform counter
	li $s1, 4 # Set number of platforms to create (0-3 = 4 platforms)
	li $s4, 896 # Set starting row position (row 7 * 128 = 896)
	li $s6, 0 # Initialize array index pointer
	add $s6, $s6, $t1 # Point to platform array base
	
starting_platform_creation_loop: 
	beq $s0, $s1, starting_platforms_complete # Exit when all platforms created
	# Generate random horizontal position for platform (0-23, platform width = 9)
	li $v0, 42 # System call for random number generation
	li $a1, 24 # Set upper bound (0-23)
	syscall # Generate random number
	
	# Convert random number to pixel position
	li $s2, 4 # Pixel width multiplier (4 bytes per pixel)
	mul $s3, $s2, $a0 # Calculate horizontal offset
	
	# Calculate absolute platform position and draw platform
	add $s5, $t0, $s4 # Add row offset to display base
	add $s5, $s5, $s3 # Add horizontal offset
	lw $s7, black_platform_color	# Load platform color
	sw $s7, 0($s5) # Draw platform pixel 1
	sw $s7, 4($s5) # Draw platform pixel 2
	sw $s7, 8($s5) # Draw platform pixel 3
	sw $s7, 12($s5) # Draw platform pixel 4
	sw $s7, 16($s5) # Draw platform pixel 5
	sw $s7, 20($s5) # Draw platform pixel 6
	sw $s7, 24($s5) # Draw platform pixel 7
	sw $s7, 28($s5) # Draw platform pixel 8
	sw $s7, 32($s5) # Draw platform pixel 9 (last pixel)
	addi $s4, $s4, 1024 # Move to next row (32 pixels * 4 bytes * 8 rows = 1024)
	addi $s0, $s0, 1 # Increment platform counter
	
	# Store platform position in array
	sw $s5, 0($s6) # Store platform address in array
	addi $s6, $s6, 4 # Move to next array position
	
	j starting_platform_creation_loop # Continue creating platforms
	

starting_platforms_complete:
	jr $ra # Return to caller

render_all_platforms:
	li $s0, 0 # Initialize platform counter
	li $s1, 4 # Set maximum platforms to draw
	la $s2, ($t1) # Load platform array address

platform_render_loop:
	beq $s0, $s1, platform_rendering_complete # Exit when all platforms drawn
	lw $s7, black_platform_color	# Load platform color
	lw $s5, 0($s2) # Load current platform position from array
	li $s3, 4 # Set pixel width (4 bytes per pixel)
	li $s4, 0 # Initialize platform width calculation
	add $s4, $s4, $t5 # Add difficulty level to width calculation
	addi $s4, $s4, 1 # Adjust width formula
	mul $s4, $s4, $s3 # Convert to byte offset for platform width
	li $s3, 0 # Initialize pixel drawing counter

platform_pixel_draw_loop:
	beq $s3, $s4, next_platform # Exit when platform width complete
	add $s6, $s5, $s3 # Calculate current pixel position
	sw $s7, 0($s6) # Draw current platform pixel
	addi $s3, $s3, 4 # Move to next pixel position
	j platform_pixel_draw_loop # Continue drawing platform pixels

next_platform:
	addi $s0, $s0, 1 # Increment platform counter
	addi $s2, $s2, 4 # Move to next platform in array
	j platform_render_loop # Continue with next platform

platform_rendering_complete:
	jr $ra # Return to caller



# Function to draw player sprite
render_player_sprite:
		lw $s1, black_sprite_color # Load sprite color
		move $s0, $t2 # Copy sprite position to working register
		sw $s1, 0($s0)              # Center
        	sw $s1, -4($s0)             # Left
        	sw $s1, 4($s0)              # Right
        	sw $s1, -128($s0)           # Up
        	sw $s1, 128($s0)            # Down
        	sw $s1, -132($s0)           # Up-left
        	sw $s1, -124($s0)           # Up-right
        	sw $s1, 132($s0)            # Down-right
        	sw $s1, 124($s0)            # Down-left

        	# Optional outer pixels to expand the circle
        	# sw $s1, -256($s0)           # Up 2
        	# sw $s1, 256($s0)            # Down 2
        	# sw $s1, -8($s0)             # Left 2
        	# sw $s1, 8($s0)              # Right 2
        	jr $ra                      # Return to caller
	


# Function to calculate score and update difficulty
calculate_and_display_score :
	lw $s1, score_text_color	# Load text color for score display
	
	# Extract individual digits from score (hundreds, tens, ones)
	li $s2, 100 # Divisor for hundreds digit
	div $t4, $s2 # Divide score by 100
	mflo $s3 # Store hundreds digit
	
	li $s2, 10 # Divisor for tens digit
	mfhi $s4  # Get remainder from hundreds division (tens + ones)
	div $s4, $s2 # Divide remainder by 10
	mflo $s4 # Store tens digit
	mfhi $s5  # Store ones digit
	
score_calculation_complete:
	jr $ra # Return to caller

# Function to render individual score digits on screen
render_score_digit:
	beq $s6, 0, draw_digit_zero # Branch to draw zero
	beq $s6, 1, draw_digit_one # Branch to draw one
	beq $s6, 2, draw_digit_two # Branch to draw two
	beq $s6, 3, draw_digit_three # Branch to draw three
	beq $s6, 4, draw_digit_four # Branch to draw four
	beq $s6, 5, draw_digit_five # Branch to draw five
	beq $s6, 6, draw_digit_six # Branch to draw six
	beq $s6, 7, draw_digit_seven # Branch to draw seven
	beq $s6, 8, draw_digit_eight # Branch to draw eight
	beq $s6, 9, draw_digit_nine # Branch to draw nine
	addi $s0, $s0, 16 # Move to next digit position if invalid digit
	jr $ra # Return to caller

# Function to calculate score digits for end game display	
calculate_final_score_display:
	lw $s1, score_text_color # Load text color for final score
	
	# Extract individual digits from final score (hundreds, tens, ones)
	li $s2, 100 # Divisor for hundreds digit
	div $t4, $s2 # Divide final score by 100
	mflo $s3 # Store hundreds digit
	
	li $s2, 10 # Divisor for tens digit
	mfhi $s4  # Get remainder from hundreds division (tens + ones)
	div $s4, $s2 # Divide remainder by 10
	mflo $s4 # Store tens digit
	mfhi $s5  # Store ones digit
	
	jr $ra # Return to caller
	
end_game_sequence:
	# Fill entire screen with lava/game over color
	jal fill_background_game_over # Paint background with lava color
	
	# Display "GAME OVER" text
	# jal draw_game_over_text
	
	# Display final score on end screen
	jal calculate_final_score_display # Calculate digits for final score
	
	# Determine number of digits and center position for end game
	li $s0, 0 # Reset screen position register
	bne $s3, 0, end_display_three_digits # If hundreds digit != 0, display 3 digits
	bne $s4, 0, end_display_two_digits   # If tens digit != 0, display 2 digits
	
end_display_one_digit:
	addi $s0, $t0, 2772  # Center position for 1 digit in end screen
	move $s6, $s5 # Move ones digit to display register
	jal render_score_digit # Draw ones digit
	j wait_for_restart
	
end_display_two_digits:
	addi $s0, $t0, 2764  # Center position for 2 digits in end screen
	move $s6, $s4 # Move tens digit to display register
	jal render_score_digit # Draw tens digit
	addi $s0, $s0, 16 # Move to next digit position
	move $s6, $s5 # Move ones digit to display register
	jal render_score_digit # Draw ones digit
	j wait_for_restart
	
end_display_three_digits:
	addi $s0, $t0, 2756  # Center position for 3 digits in end screen
	move $s6, $s3 # Move hundreds digit to display register
	jal render_score_digit # Draw hundreds digit
	addi $s0, $s0, 16 # Move to next digit position
	move $s6, $s4 # Move tens digit to display register
	jal render_score_digit # Draw tens digit
	addi $s0, $s0, 16 # Move to next digit position
	move $s6, $s5 # Move ones digit to display register
	jal render_score_digit # Draw ones digit

wait_for_restart:
	# Wait for 's' key to restart or any other key to exit
	lw $s0, 0xffff0000 # Load keyboard control register
	beq $s0, 1, check_restart_key # If key is pressed, check it
	j wait_for_restart # Keep waiting for input
	
check_restart_key:
	lw $s1, 0xffff0004 # Load the actual key value
	beq $s1, 115, restart_game # If key is 's' (ASCII 115), restart game
	li $v0, 10 # System call to terminate program
	syscall # End program execution for any other key

restart_game:
	# Reset all game variables to initial state
	li $t3, 0 # Reset jump counter
	li $t4, 0 # Reset score counter
	li $t5, 8 # Reset difficulty level
	li $t6, 1 # Reset difficulty tracking variable
	j main # Jump back to main to restart the game

# Functions to draw each digit (0-9) using pixel patterns

draw_digit_zero:
	lw $s1, score_text_color     #Setting the color in $s1
	sw $s1, 0($s0)		#Filling 
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 384($s0)
	sw $s1, 512($s0)
	sw $s1, 516($s0)
	sw $s1, 520($s0)
	sw $s1, 392($s0)
	sw $s1, 264($s0)
	sw $s1, 136($s0)
	jr $ra
	
draw_digit_one:
	lw $s1, score_text_color # Load text color
	sw $s1, 4($s0) # Draw top center pixel
	sw $s1, 132($s0) # Draw diagonal pixel
	sw $s1, 128($s0) # Draw left support pixel
	sw $s1, 260($s0) # Draw center column pixel row 3
	sw $s1, 388($s0) # Draw center column pixel row 4
	sw $s1, 516($s0) # Draw center column pixel row 5
	jr $ra # Return to caller
	
draw_digit_two:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 4($s0) # Draw top-center pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 136($s0) # Draw right side pixel row 2
	sw $s1, 256($s0) # Draw middle-left pixel
	sw $s1, 260($s0) # Draw middle-center pixel
	sw $s1, 264($s0) # Draw middle-right pixel
	sw $s1, 384($s0) # Draw left side pixel row 4
	sw $s1, 520($s0) # Draw bottom-right pixel
	sw $s1, 516($s0) # Draw bottom-center pixel
	sw $s1, 512($s0) # Draw bottom-left pixel
	jr $ra # Return to caller
	
draw_digit_three:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 4($s0) # Draw top-center pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 136($s0) # Draw right side pixel row 2
	sw $s1, 256($s0) # Draw middle-left pixel
	sw $s1, 260($s0) # Draw middle-center pixel
	sw $s1, 264($s0) # Draw middle-right pixel
	sw $s1, 392($s0) # Draw right side pixel row 4
	sw $s1, 512($s0) # Draw bottom-left pixel
	sw $s1, 516($s0) # Draw bottom-center pixel
	sw $s1, 520($s0) # Draw bottom-right pixel
	jr $ra # Return to caller
	
draw_digit_four:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 128($s0) # Draw left side pixel row 2
	sw $s1, 136($s0) # Draw right side pixel row 2
	sw $s1, 256($s0) # Draw middle-left pixel
	sw $s1, 260($s0) # Draw middle-center pixel
	sw $s1, 264($s0) # Draw middle-right pixel
	sw $s1, 392($s0) # Draw right side pixel row 4
	sw $s1, 520($s0) # Draw right side pixel row 5
	jr $ra # Return to caller
	
draw_digit_five:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 4($s0) # Draw top-center pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 128($s0) # Draw left side pixel row 2
	sw $s1, 256($s0) # Draw middle-left pixel
	sw $s1, 260($s0) # Draw middle-center pixel
	sw $s1, 264($s0) # Draw middle-right pixel
	sw $s1, 392($s0) # Draw right side pixel row 4
	sw $s1, 520($s0) # Draw bottom-right pixel
	sw $s1, 516($s0) # Draw bottom-center pixel
	sw $s1, 512($s0) # Draw bottom-left pixel
	jr $ra # Return to caller
	
draw_digit_six:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 4($s0) # Draw top-center pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 128($s0) # Draw left side pixel row 2
	sw $s1, 256($s0) # Draw middle-left pixel
	sw $s1, 260($s0) # Draw middle-center pixel
	sw $s1, 264($s0) # Draw middle-right pixel
	sw $s1, 392($s0) # Draw right side pixel row 4
	sw $s1, 520($s0) # Draw bottom-right pixel
	sw $s1, 516($s0) # Draw bottom-center pixel
	sw $s1, 512($s0) # Draw bottom-left pixel
	sw $s1, 384($s0) # Draw left side pixel row 4
	jr $ra # Return to caller
	
draw_digit_seven:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 4($s0) # Draw top-center pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 136($s0) # Draw right side pixel row 2
	sw $s1, 264($s0) # Draw right side pixel row 3
	sw $s1, 392($s0) # Draw right side pixel row 4
	sw $s1, 520($s0) # Draw right side pixel row 5
	jr $ra # Return to caller
	
draw_digit_eight:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 4($s0) # Draw top-center pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 128($s0) # Draw left side pixel row 2
	sw $s1, 136($s0) # Draw right side pixel row 2
	sw $s1, 256($s0) # Draw middle-left pixel
	sw $s1, 260($s0) # Draw middle-center pixel
	sw $s1, 264($s0) # Draw middle-right pixel
	sw $s1, 384($s0) # Draw left side pixel row 4
	sw $s1, 392($s0) # Draw right side pixel row 4
	sw $s1, 520($s0) # Draw bottom-right pixel
	sw $s1, 516($s0) # Draw bottom-center pixel
	sw $s1, 512($s0) # Draw bottom-left pixel
	jr $ra # Return to caller
	
draw_digit_nine:
	lw $s1, score_text_color # Load text color
	sw $s1, 0($s0) # Draw top-left pixel
	sw $s1, 4($s0) # Draw top-center pixel
	sw $s1, 8($s0) # Draw top-right pixel
	sw $s1, 128($s0) # Draw left side pixel row 2
	sw $s1, 136($s0) # Draw right side pixel row 2
	sw $s1, 256($s0) # Draw middle-left pixel
	sw $s1, 260($s0) # Draw middle-center pixel
	sw $s1, 264($s0) # Draw middle-right pixel
	sw $s1, 392($s0) # Draw right side pixel row 4
	sw $s1, 520($s0) # Draw bottom
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra

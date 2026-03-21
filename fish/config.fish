fish_add_path $HOME/.local/bin

if status is-interactive
	if test (tty) = "/dev/tty1"
		exec start-hyprland
	end
end

starship init fish | source
zoxide init fish | source

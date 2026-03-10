New-NetFirewallRule -DisplayName "Allow-P2P-TCP" `
	-Direction Inbound `
	-Action Allow `
	-Protocol TCP `
	-LocalPort 6881-6999 `
	-Profile Any

New-NetFirewallRule -DisplayName "Allow-P2P-UDP" `
	-Direction Inbound `
	-Action Allow `
	-Protocol UDP `
	-LocalPort 6881-6999 `
	-Profile Any

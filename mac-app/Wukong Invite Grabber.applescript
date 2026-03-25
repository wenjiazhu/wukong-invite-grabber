on run
	try
		set launcherPath to POSIX path of (path to resource "start_wukong_invite_grabber.sh")
		do shell script "/bin/chmod +x " & quoted form of launcherPath & " && " & quoted form of launcherPath
	on error errMsg number errNum
		display dialog "启动 Wukong Invite Grabber 失败：" & return & errMsg buttons {"关闭"} default button "关闭" with icon stop
	end try
end run

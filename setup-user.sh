export USER=$(python3 -c 'import pwd, os; print(pwd.getpwuid(os.getuid()).pw_name)')
export HOME=$(python3 -c 'import pwd, os; print(pwd.getpwuid(os.getuid()).pw_dir)')
cp -nr /etc/skel/* $HOME/

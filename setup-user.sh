export USER=$(python3 -c 'import pwd, os; print(pwd.getpwuid(os.getuid()).pw_name)')
export HOME=$(python3 -c 'import pwd, os; print(pwd.getpwuid(os.getuid()).pw_dir)')
if [ ! -r $HOME/.bash_profile ]
then
    cat > $HOME/.bash_profile << EOF
if [ -r ~/.bashrc ]; then source ~/.bashrc; fi
EOF
fi
if [ ! -r $HOME/.bashrc ]
then
    cat > $HOME/.bashrc << EOF
# This is the bashrc file
cp -nr /etc/skel/* $HOME/
EOF
fi

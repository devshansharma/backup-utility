#! /bin/bash


# This utility will take back up of files and folders, check their checksum
# and move backup files to pendrive


# ------------------------------------------------
# important variables 
# ------------------------------------------------

CONFIG_DIR='/.backup_config.d/'
CHECKSUM_FILE='checksum.txt'
MAIN_FILE='config.sh'

CONFIG_PATH="${HOME}${CONFIG_DIR}"
CHECKSUM_PATH="${CONFIG_PATH}${CHECKSUM_FILE}"
MAIN_FILE_PATH="${CONFIG_PATH}${MAIN_FILE}"


# ------------------------------------------------
# functions 
# ------------------------------------------------

# backup from list of directories
execute_backup () {
	local src_path
	local dst_path
	local excludeList
	source $MAIN_FILE_PATH	

	for entry in "$CONFIG_PATH"*
	do
		b=$(basename $entry)
		if [[ $b =~ "rules" ]];then
			echo "Reading rules file: $b"
			src_path=$HOME/$(grep "SOURCE_PATH" $entry | cut -d= -f2)
			dst_path=$(grep "DESTINATION_PATH" $entry | cut -d= -f2)
			excludeList=$(grep "EXCLUDE" $entry | cut -d= -f2-)
			if [[ "$dst_path" == '' ]];then
				dst_path=$HOME/$DEFAULT_DESTINATION
			fi
			archive
		fi
	done
}

execute_single_backup () {
	local src_path
	local dst_path
	local excludeList
	source $MAIN_FILE_PATH	

	for entry in "$CONFIG_PATH"*
	do
		b=$(basename $entry)
		if [[ $b == $1 ]];then
			echo "Reading rules file: $b"
			src_path=$HOME/$(grep "SOURCE_PATH" $entry | cut -d= -f2)
			dst_path=$(grep "DESTINATION_PATH" $entry | cut -d= -f2)
			excludeList=$(grep "EXCLUDE" $entry | cut -d= -f2-)
			if [[ "$dst_path" == '' ]];then
				dst_path=$HOME/$DEFAULT_DESTINATION
			fi
			archive
		fi
	done
}

# archive files from source to destination
archive () {
	local tar='tar'

	echo "Creating backup as per rule file, with following configuration:"	
	echo -e "Source Path     \t\t: $src_path"
	echo -e "Destination Path\t\t: $dst_path"
	echo -e "Excluding Files \t\t: $excludeList"
	
	for e in $excludeList
	do
		tar="$tar --exclude='${e}'"
	done
	
	mkdir -p $dst_path
	file_name="$(basename $src_path).tar.gz"

	tar="$tar -czf ${dst_path}/$file_name -C ${src_path} ."
	eval $tar
	
	# useful when taking backup to pendrive.
	md5sum ${dst_path}/$file_name > ${dst_path}/${file_name}.checksum.txt

       	echo	
}

# overriding command
# an example to remember
ls () {
	command ls
	#command ls -lh
}

# read file and print on screen
readFile () {
	source $MAIN_FILE_PATH	

	echo -e "Rule File: $1\n"
	for entry in "$CONFIG_PATH"*
	do
		b=$(basename $entry)
		if [[ $b =~ "rules" ]];then
			if [[ $b == $1 ]]; then
				cat $CONFIG_PATH/$b
			fi
		fi
	done
	echo ""
}

# read file and print on screen
delFile () {
	source $MAIN_FILE_PATH	

	for entry in "$CONFIG_PATH"*
	do
		b=$(basename $entry)
		if [[ $b =~ "rules" ]];then
			if [[ $b == $1 ]]; then
				rm $CONFIG_PATH/$b
				if [[ $? == 0 ]]; then
					echo -e "$b file deleted successfully."
				fi
			fi
		fi
	done
	echo ""
}

# list all the rules file we have, with the folder to take backup
listRules () {
	local b
	local src_path

	echo -e "Rules File\t\t\tFolders For Backup"
	echo -e "----------\t\t\t------------------"
	for entry in "$CONFIG_PATH"*
	do
		b=$(basename $entry)
		if [[ $b =~ "rules" ]];then
			src_path=$(grep "SOURCE_PATH" $entry | cut -d= -f2)
			echo -e "$b\t\t\t$src_path"
		fi
	done
	echo ""
}

# create rules for backup, each file created will contain rule for 1 folder backup
createNewRule () {
	# to get filename of last rules file, 
	local b
	local source_path
	local dest_path
	local newNum=0
	local num
	local excludeFile
	declare -a excludeArray

	for entry in "$CONFIG_PATH"*
	do
		b=$(basename $entry)
		if [[ $b =~ "rules" ]]
		then
			#echo "Rule File Found: $b"
			num=$(echo $b | sed 's/rules//g' | sed 's/.txt//g')
			if [ $num -gt $newNum ];then
				newNum="$num"
			fi
			#echo $newNum
		fi
	done
	newNum=$((newNum + 1))

	source $MAIN_FILE_PATH

	# create rules
	echo "Creating rules file: "
	read -p "[1] Enter the source file/folder path: ${HOME}/" source_path
	read -p "[2] Enter the destination folder path (default $HOME/$DEFAULT_DESTINATION): " dest_path
	echo "[3] Enter files/folders to exclude from backup (Ctrl+D to exit): "
	while read excludeFile
	do
		excludeArray=(${excludeArray[@]} $excludeFile)
	done

	# printing data to file, creating rules[:number].txt
	cat <<EOF >$CONFIG_PATH/rules${newNum}.txt
SOURCE_PATH=$source_path
DESTINATION_PATH=$dest_path
EXCLUDE=${excludeArray[@]}
EOF
	echo -e "Rule File Created: rules${newNum}.txt\n"
}

makeConfig () {
	local dest_path
	echo "Create global config rules: "
	read -p "[1] Specify default destination path (starts with ${HOME}/): " dest_path
	echo "DEFAULT_DESTINATION=\"${dest_path}\"" > $MAIN_FILE_PATH
	chmod +x $MAIN_FILE_PATH
	echo -e "Backup Configuration File Created.\n"
}

# first function to execute
init () {
	echo -e "\n\t\tBackup Utility - by Shadow\n"

	if [ "$EUID" -ne 0 ]; then
		echo -e "Please run as root, if your config file paths are in root folder.";
		#exit
	fi

	# if backup config folder does not exist, create one
	[ ! -d "${CONFIG_PATH}" ] && mkdir -p "${CONFIG_PATH}"

	# check if config file not exists, create one
	[ ! -f "${MAIN_FILE_PATH}" ] && touch $MAIN_FILE_PATH


	if [ "$1" == "--config" ]; then
		makeConfig
		return 0
	fi

	if [ "$1" == "--new" ]; then
		createNewRule
		return 0
	fi	

	if [ "$1" == "--list-rules" ]; then
		listRules
		return 0
	fi

	if [ "$1" == "--read-file" ]; then
		readFile $2
		return 0
	fi

	if [ "$1" == "--del-file" ]; then
		delFile $2
		return 0
	fi

	if [ "$1" == "--backup" ]; then
		execute_backup	
		return 0
	fi	

	if [ "$1" == "--single-backup" ]; then
		execute_single_backup $2	
		return 0
	fi	

	if [ "$1" == "--create-alias" ];then
		mypath=$(realpath $0)	
		echo "alias mybackup='bash $mypath'" >> ${HOME}/.bash_aliases
		echo -e "Alias created in .bash_aliases.\n"
		source ~/.bashrc
		return 0
	fi

	echo -e "Please specify arguments."
	echo -e "--create-alias         \t\tTo create alias for backup utility in .bash_aliases file."
	echo -e "--config               \t\tTo create configuration file."
	echo -e "--new                  \t\tTo create rule file for a folder."
	echo -e "--list-rules           \t\tTo see rule files with source path."
	echo -e "--read-file <rule1.txt>\t\tTo read a specific rule file."
	echo -e "--del-file <rule1.txt> \t\tTo delete a specific rule file."
	echo -e "--single-backup        \t\tTo execute backup of single rule file."
	echo -e "--backup               \t\tTo execute backup by following all rules file.\n"
	return 1
}

init $1 $2





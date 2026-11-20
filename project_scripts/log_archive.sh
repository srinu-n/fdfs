#!/bin/bash


if [ $(id -u) -eq 0 ];then
    echo " user have root previlages"
else
    echo "please run with the root permissions"
    exit 1
fi

files_to_delete=$(find /var/log/ -type f -name "fdfs-*.log*"  -mtime +6)

if [ -n "${files_to_delete}" ]; then
    echo "there are files to delete.. going a head"
    echo "${files_to_delete}"

else
     echo "there is no more files older than 7 days"
    exit 0
fi

while IFS= read -r files; do

if [ -f "$files" ];then  # ideally checking is not required since the find itself return only #the files if there are means otherwise it wont
    echo "comporessing  the $files"
    new_name="${files}.$(date +%Y%m%d)-$(hostname)"
    mv "${files}" "${new_name}"
    gzip -9 "${new_name}"
    aws s3 cp "${new_name}".gz s3://fdfs-log-archive-test-88b1b745/logs/  
        if [ $? -eq 0 ]; then
            echo "${new_name}.gz copied sucessfully.. so going to delete the file"
            rm -f "${new_name}.gz"
        else   
            echo "${new_name}.gz upload failed..."
            exit 1
        fi
fi
done  <<< "${files_to_delete}"  # < when it is a file

### <<< when it a variable
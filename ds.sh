#!/data/data/com.termux/files/usr/bin/bash
#Made in DeepSeek!
export LANG="zh_CN.UTF-8"

# 配置API端点
API_URL="https://api.deepseek.com/v1/chat/completions"

# 获取API密钥
API_KEY=''

# 处理命令行参数
stream_mode=""
model=""

while getopts ":sSrR" opt; do
	case $opt in
		s)
			stream_mode=true
			;;
		S)
			stream_mode=false
			;;
		r)
			model="deepseek-reasoner"
			;;
		R)
			model="deepseek-chat"
			;;
		\?)
			echo "⚠️ 无效选项: -$OPTARG" >&2
			;;
	esac
done

# 未提供流式选项时提示用户
if [[ -z "$stream_mode" ]]; then
	read -p "请选择对话模式 (s:流式/S:非流式): " mode
	if [[ "$mode" == "S" ]]; then
		stream_mode=false
		echo "✅ 已选择非流式模式"
	else
		stream_mode=true
		echo "✅ 已选择流式模式"
	fi
fi

# 未提供模型选项时提示用户
if [[ -z "$model" ]]; then
	read -p "请选择模型 (r:推理模型/R:对话模型): " model_choice
	if [[ "$model_choice" == "r" ]]; then
		model="deepseek-reasoner"
		echo "✅ 已选择推理模型"
	else
		model="deepseek-chat"
		echo "✅ 已选择对话模型"
	fi
fi

# 初始化对话历史
history=()

# 设置提示符
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GRAY_DARK='\033[0;90m'
NC='\033[0m' # 无颜色
if $stream_mode; then
	note="$model stream"
else
	note="$model not-stream"
fi
# 对话循环（主循环体）
while true; do
	echo -e "${GREEN}${note} ${NC}\$ "
	# 获得用户输入
	user_input=""
	while true; do
		read -e -p "" input
		#退出信号
		if [[ "$input" == "exit" ]]; then
			user_input="EXIT"
			break
		fi
		#发送消息信号（并且给出AI提示符）
		if [[ "$input" == "sent" ]]; then
			echo -e "\033[2K\033[1A${BLUE}${note} ${NC}# "
			break
		fi
		#文件附带信号
		if [[ "$input" == "file" ]]; then
			echo -e "\033[2K\033[1A${YELLOW}FILE_PATH:${GRAY_DARK}"
			read -e -p "" path
			echo -ne "${NC}"
			input=$(cat "$path")
		fi
		#无信号则拼接输入内容
		user_input+="$input"
		user_input+=$(echo -e " \n ")
	done
	#退出主循环体（关闭脚本）
	if [[ "$user_input" == "EXIT" ]]; then
		break
	fi
	# 转义特殊字符
	escaped_input=$(jq -aRs . <<< "$user_input")
	# 日志
	echo "${user_input}" >> .log
	# 添加到对话历史
	history+=("{\"role\": \"user\", \"content\": ${escaped_input}}")

	# 构建请求JSON
	messages_json=$(printf '%s\n' "${history[@]}" | jq -s '.')
	request_data=$(cat <<EOF
{
	"model": "$model",
	"messages": $messages_json,
	"stream": $stream_mode
}
EOF
		)

	# 处理不同模式
	if $stream_mode; then
	# 流式模式 - 使用临时文件收集完整响应
	tmpfile=$(mktemp)
	curl -s -N -X POST "$API_URL" \
		-H "Authorization: Bearer $API_KEY" \
		-H "Content-Type: application/json" \
		-d "$request_data" \
		| {
			full_response=""
			while IFS= read -r line; do
				# 忽略空行和心跳信号
				if [[ -z "$line" ]] || [[ "$line" == ":"* ]]; then
					continue
				fi

				# 处理SSE数据行
				if [[ $line == data:* ]]; then
					# 提取JSON部分
					json_data="${line#data: }"
					# 检查结束标记
					if [[ "$json_data" == "[DONE]" ]]; then
						# 保存完整响应到临时文件
						echo -n "$full_response" > "$tmpfile"
						break
					fi
					# 解析内容
					content=$(echo "$json_data" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
					if [ -n "$content" ]; then
						# 实时输出内容
						printf "%s" "$content"
						full_response+="$content"
					fi
				fi
			done
		}
		# 从临时文件读取完整响应
		full_response=$(<"$tmpfile")
		# 日志
		echo "$full_response" >>.log
			rm -f "$tmpfile"
			echo  # 确保助手回复后有换行
	else
		# 非流式模式 - 一次性获取完整响应
		response=$(curl -s -X POST "$API_URL" \
			-H "Authorization: Bearer $API_KEY" \
			-H "Content-Type: application/json" \
			-d "$request_data")
		# 解析响应
		full_response=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null)
		# 输出响应
		if [ -n "$full_response" ]; then
			echo "$full_response"
			# 日志
			echo "$full_response" >>.log
		else
			echo "⚠️ 解析响应失败，原始响应:"
			echo "$response"
		fi
	fi

	# 将助手回复添加到历史（仅当有实际内容时）
	if [ -n "$full_response" ]; then
		escaped_response=$(jq -aRs . <<< "$full_response")
		history+=("{\"role\": \"assistant\", \"content\": ${escaped_response}}")
	else
		# 只在真正没有响应时显示错误
		echo "⚠️ 未收到有效响应，请检查API密钥和网络连接"
	fi
done


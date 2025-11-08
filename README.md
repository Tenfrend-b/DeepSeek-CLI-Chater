# DeepSeek-CLI-Chater
A very simple bash script to chat with DeepSeek using DeepSeek API key Generating by DeepSeek.

用法：bash ds.sh &lt;option&gt;

支持的选项为S s R r，分别对应非流式对话 流式对话 对话模型 推理模型。

对话过程中回车为换行文本，输入sent发送文本（不是笔误，就是sent，有意为之）；输入file可以cat一个指定路径的文本文件的内容附加入发送文本中；输入exit退出对话。

出于未知原因，流式对话会丢失换行信息，因此能用非流式就用非流式。

脚本会自动在工作目录下生成.log文件作为日志，将其链接为某个.md文件可能能提高可读性。

请手动填写脚本中的API_KEY以使其正常运行。

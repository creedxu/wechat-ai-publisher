# WeChat AI Publisher Skill

自动发布文章到微信公众号草稿箱的工具。支持HTML文章、封面图片、自动排版。

## 功能

- 将HTML文章发布到微信公众号草稿箱
- 自动上传封面图片
- 支持多图上传
- 自动处理微信公众号的格式要求
- 提供发布状态跟踪

## 使用方法

### 基本发布

```python
from wechat_publisher import WeChatPublisher

# 初始化发布器
publisher = WeChatPublisher(app_id="YOUR_APP_ID", app_secret="YOUR_APP_SECRET")

# 发布文章
result = publisher.publish_article(
    title="文章标题",
    content="<html>文章内容</html>",
    cover_img_path="封面图片路径.jpg"
    digest="文章摘要",
    
)

if result["success"]:
    print(f"文章已发布到草稿箱，ID: {result['media_id']}")
else:
    print(f"发布失败: {result['error']}")
```

### 在OpenClaw中调用

当用户需要发布文章到微信公众号时，使用此技能：

1. 确保已配置公众号凭证（app_id, app_secret）
2. 准备好HTML文章内容
3. 调用发布功能

## 配置

### 环境变量

```bash
export WECHAT_APP_ID="your_app_id"
export WECHAT_APP_SECRET="your_app_secret"
```

### 配置文件

也可在 `config.json` 中配置：

```json
{
  "wechat": {
    "app_id": "your_app_id",
    "app_secret": "your_app_secret"
  }
}
```

## 依赖安装

```bash
pip install requests requests_toolbelt Pillow
```


## 注意事项

1. 需要微信公众号的开发者权限
2. 确保网络可访问微信API服务器
3. 文章内容需符合微信公众号规范
4. 图片大小和格式需符合微信要求

## 错误处理

常见错误：
- `40001`: 获取access_token失败
- `40002`: 参数错误
- `40007`: 图片上传失败
- `48001`: API未授权

## 示例

完整示例请参考 `examples/` 目录。

## 作者

creedxu (GitHub)
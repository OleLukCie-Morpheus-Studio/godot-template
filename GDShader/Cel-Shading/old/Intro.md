

### **一、CelShadingShader（卡通渲染着色器）**

#### 核心功能

实现卡通风格渲染（Cel Shading），核心特征包括**明暗分块阴影、可控高光、轮廓线融合**，模拟手绘动画的视觉效果。

#### 关键参数与逻辑拆解

1. **基础配置** 
- `shader_type spatial`：用于3D空间渲染（适用于模型表面）。 
- `render_mode ambient_light_disabled`：关闭环境光，避免光照过渡柔和（卡通渲染需要明暗对比强烈）。 
2. **Uniform变量（外部可调节参数）** 
- 纹理采样器： 
- `base:hint_albedo`：基础颜色纹理（物体固有色）。 
- `sss:hint_albedo`：次表面散射/阴影颜色纹理（阴影区域的颜色偏移，如皮肤阴影偏红）。 
- `ilm:hint_albedo`：综合信息纹理（多通道复用）： 
- `aaa`（alpha通道）：轮廓线颜色（控制轮廓强度）。 
- `g`（绿色通道）：阴影权重（控制阴影区域的明暗程度）。 
- `r`（红色通道）：高光遮罩（控制高光是否生效的区域）。 
- `b`（蓝色通道）：高光形状（控制高光的范围）。 
- 数值参数： 
- `shinese`/`shininess`：高光锐度（值越高，高光范围越窄）。 
- `shade_threshold`：阴影阈值（0-1，控制明暗分块的临界点，值越高，阴影区域越大）。 
- `spec_threshold`：高光阈值（0-0.01，控制高光是否显示的临界点，值越低，高光越容易出现）。 
3. **顶点函数（vertex）** 
- `v_color = COLOR`：将模型顶点颜色传递给片段着色器（用于后续AO/衰减权重，如`fade_ao_weight = v_color.r`）。 
4. **光照函数（light）** 
- **漫反射逻辑（明暗分块）**： 
- 计算`LdotN = dot(LIGHT, NORMAL)`（光线方向与法线方向的点积，值越大，光照越直接）。 
- 结合`shadow_weight`（ilm的g通道）和`fade_ao_weight`（顶点颜色r通道）得到`shade`（综合光照强度）。 
- 通过`step(shade_threshold, shade)`判断是否为“受光区”： 
- 受光区：`DIFFUSE_LIGHT += base_color`（直接使用基础色）。 
- 阴影区：`DIFFUSE_LIGHT += (base_color + fade_ao_weight) * shade_color`（混合基础色与sss阴影色，增加阴影层次）。 
- 最终`DIFFUSE_LIGHT *= outline_color`（叠加ilm的alpha通道轮廓色，强化边缘）。 
- **高光逻辑（卡通高光）**： 
- 计算`halfwayDir`（光线与视角的半程向量），通过`pow(dot(NORMAL, halfwayDir), shininess)`得到高光强度。 
- 用`spec_mask`（ilm的r通道）限制高光区域，`spec_shape`（ilm的b通道）控制高光形状。 
- 通过`step(spec_threshold, spec*spec_shape)`判断是否显示高光，最终叠加到`SPECULAR_LIGHT`。 
5. **渲染效果** 
- 明暗过渡呈“块状”（无渐变），符合卡通风格； 
- 高光集中且边缘清晰（如金属反光、角色高光）； 
- 轮廓线通过ilm纹理控制，可与模型颜色融合。 
  
  ### **二、DecalHighlightShader（贴花高亮着色器）**
  
  #### 核心功能
  
  实现模型表面的**贴花高亮效果**（如交互提示、弱点标记），通过贴花纹理控制高亮区域和透明度。
  
  #### 关键参数与逻辑拆解
1. **基础配置** 
- `shader_type spatial`：3D空间渲染。 
- `render_mode ambient_light_disabled`：关闭环境光，避免高亮被环境光稀释。 
2. **Uniform变量** 
- `decal`：贴花纹理（控制高亮区域和强度，通常用单通道或RGB定义高亮颜色）。 
- `base`：基础纹理（未直接使用，可能预留用于混合基础色）。 
3. **光照函数（light）** 
- 采样贴花颜色：`decal_color = texture(decal, UV)`。 
- 透明度控制：`ALPHA = (decal_color.r - 0.5) / 0.5` 
- 当`decal_color.r = 1.0`时，`ALPHA = 1.0`（完全不透明）； 
- 当`decal_color.r = 0.5`时，`ALPHA = 0`（完全透明）； 
- 仅用红色通道控制透明度，适合单通道贴花图（如灰度图）。 
- 高亮强度：`DIFFUSE_LIGHT += decal_color.rgb / 0.5` 
- 贴花颜色被放大2倍（`/0.5`），强化高亮效果； 
- 若贴花为红色（`rgb=(1,0,0)`），则高亮为红色且强度翻倍。 
4. **渲染效果** 
- 贴花区域显示高亮颜色，非贴花区域透明（不影响模型原有外观）； 
- 适合标记交互点（如“可拾取物品”）或弱点（如怪物要害）。 
  
  ### **三、OutlineStrokeShader（轮廓线着色器）**
  
  #### 核心功能
  
  为模型生成**边缘轮廓线**（如卡通角色的黑色外轮廓），通过顶点偏移和背面渲染实现。
  
  #### 关键参数与逻辑拆解
1. **基础配置** 
- `shader_type spatial`：3D空间渲染。 
- `render_mode unshaded, cull_front`： 
- `unshaded`：忽略光照，轮廓色不受光照影响； 
- `cull_front`：剔除正面（仅显示背面），配合顶点偏移形成“包裹原模型”的轮廓。 
2. **Uniform变量** 
- `strength:hint_range(0,0.01) = 0.002`：轮廓强度（控制偏移量，值越大，轮廓越粗）。 
3. **顶点函数（vertex）** 
- 核心：通过顶点偏移生成轮廓，偏移量由多因素控制： 
- `offset = NORMAL`：基于法线方向偏移（向模型外部扩张）。 
- `v2c_dist`：模型顶点到相机的距离（`clamp`限制在0-50，避免远距离轮廓过粗）。 
- `COLOR`通道控制： 
- `COLOR.b`：影响z轴偏移（可能用于调整轮廓在深度方向的显示，避免穿透）； 
- `COLOR.a`：轮廓整体透明度（间接控制偏移生效范围）； 
- `COLOR.g`：轮廓粗细系数（局部调整，如关节处轮廓更粗）。 
- 最终偏移：`VERTEX += offset * strength * COLOR.a * v2c_dist * COLOR.g` 
- 距离相机越近（`v2c_dist`小），轮廓越细；颜色alpha/g值越高，轮廓越明显。 
4. **片段函数（fragment）** 
- `ALBEDO = vec3(0f)`：轮廓颜色为纯黑色（可通过修改此值调整颜色）。 
5. **渲染效果** 
- 模型边缘生成黑色轮廓，粗细随距离、顶点颜色动态变化； 
- 无光照影响，轮廓清晰，适合卡通、UI指示等场景。 
  
  ### **总结**
  
  三个着色器可配合使用，形成完整的卡通风格渲染管线： 
- `CelShadingShader`：负责主体明暗、高光、基础轮廓融合； 
- `OutlineStrokeShader`：生成独立的外轮廓线，强化边缘； 
- `DecalHighlightShader`：叠加高亮贴花，实现交互标记或特效。 
  



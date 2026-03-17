## MODIFIED Requirements

### Requirement: 文件选择交互

系统 SHALL 提供单选模式的文件选择界面。

#### Scenario: 单选文件
- **WHEN** 用户点击文件列表中的某个文件
- **THEN** 仅选中该文件，之前选中的文件自动取消选中

#### Scenario: 取消选择
- **WHEN** 用户点击已选中的文件
- **THEN** 取消选中该文件，无任何文件被选中

#### Scenario: 确认选择
- **WHEN** 用户点击"加载"按钮
- **THEN** 加载当前选中的文件，如无选中文件则禁用加载按钮

#### Scenario: 显示选中状态
- **WHEN** 某个文件被选中
- **THEN** 该文件显示明显的选中指示（如高亮背景或 Radio 按钮选中状态）

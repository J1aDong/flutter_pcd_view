## MODIFIED Requirements

### Requirement: 离群点去除开关控制

系统 SHALL 允许用户独立启用和禁用 SOR 和 ROR 离群点去除功能。

#### Scenario: 启用 SOR
- **WHEN** 用户打开 SOR 开关
- **THEN** SOR 功能启用，显示 SOR 参数设置

#### Scenario: 禁用 SOR
- **WHEN** 用户关闭 SOR 开关
- **THEN** SOR 功能禁用，SOR 参数设置隐藏，设置保存为 null

#### Scenario: 启用 ROR
- **WHEN** 用户打开 ROR 开关
- **THEN** ROR 功能启用，显示 ROR 参数设置

#### Scenario: 禁用 ROR
- **WHEN** 用户关闭 ROR 开关
- **THEN** ROR 功能禁用，ROR 参数设置隐藏，设置保存为 null

#### Scenario: 独立控制
- **WHEN** 用户修改一个离群点去除设置
- **THEN** 另一个离群点去除设置不受影响

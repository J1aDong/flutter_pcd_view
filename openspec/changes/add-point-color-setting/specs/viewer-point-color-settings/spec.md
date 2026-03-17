## ADDED Requirements

### Requirement: Viewer SHALL support configurable point color
查看器 SHALL 提供独立的点颜色配置，用于控制未携带自定义颜色的点在渲染时的默认颜色。

#### Scenario: Use configured point color as default point color
- **WHEN** 调用方在 `ViewerConfig` 中设置点颜色，且点数据未提供可用的自定义颜色
- **THEN** 查看器 SHALL 使用配置的点颜色渲染这些点

#### Scenario: Preserve explicit point color from source data
- **WHEN** 点数据本身提供了明确的颜色值
- **THEN** 查看器 SHALL 保留点数据原有颜色，而不是被默认点颜色配置覆盖

### Requirement: Viewer point color SHALL be configurable from example settings
example 应用 SHALL 在查看器设置页中提供点颜色调节入口，并将其放在“背景颜色”下方。

#### Scenario: Adjust point color from settings page
- **WHEN** 用户在 example 设置页调整点颜色
- **THEN** 查看器 SHALL 在后续渲染中使用新的点颜色配置

#### Scenario: Persist point color setting
- **WHEN** 用户修改点颜色后退出并重新进入 example
- **THEN** 设置页与查看器 SHALL 恢复上次保存的点颜色配置

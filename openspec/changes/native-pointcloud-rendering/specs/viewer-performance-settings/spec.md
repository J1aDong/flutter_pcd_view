## ADDED Requirements

### Requirement: Native rendering performance settings
系统 SHALL 提供面向 native renderer 的性能配置项，用于控制点预算、上传策略和渲染质量，而不是只面向 Flutter 渲染链。

#### Scenario: Configure point budget
- **WHEN** 调用方设置最大渲染点数预算
- **THEN** native renderer SHALL 将点数控制在该预算内再提交绘制

#### Scenario: Configure render quality
- **WHEN** 调用方设置 native renderer 的渲染质量档位或等价参数
- **THEN** native renderer SHALL 按对应质量参数更新渲染行为

## MODIFIED Requirements

### Requirement: Settings integration with PcdView
The PcdView widget SHALL accept and apply optimization settings as well as native rendering settings.

#### Scenario: Apply settings from config
- **WHEN** PcdView is created with a PerformanceConfig
- **THEN** the optimization settings and native rendering settings SHALL be used during point cloud loading and rendering

# OpenLACores Contribution and Collaboration Guidelines

Thank you for your interest in and contribution to OpenLACores. We welcome developers, researchers, and enthusiasts to improve the project through issue reports, documentation, verification, bug fixes, and feature development.

These guidelines apply to RTL, simulation and differential testing, FPGA projects, software tests, scripts, and documentation in this repository. Read the documentation relevant to your change before contributing. For environment setup, see [Environment Setup](environment_setup.md); for Verilator simulation and testing, see the [verification guide](../verify/verilator/README_en.md).

## Contents

- [Before You Contribute](#before-you-contribute)
- [Reporting Issues and Proposing Changes](#reporting-issues-and-proposing-changes)
- [Development and Commits](#development-and-commits)
- [Verification Requirements](#verification-requirements)
- [Pull Requests and Review](#pull-requests-and-review)
- [Documentation, Licensing, and Third-Party Content](#documentation-licensing-and-third-party-content)
- [Use of AI Assistance](#use-of-ai-assistance)
- [Contact](#contact)

## Before You Contribute

Before opening an issue or submitting a change, please:

- Read the root [README](../README_en.md), the README files in relevant directories, and the documentation for affected interfaces, configurations, and boot flows.
- Search existing issues, discussions, and changes to avoid duplicating work.
- Reproduce the issue with the relevant branch, configuration, and test image. For behavioral changes, first confirm that the issue still reproduces on the current mainline.
- Keep temporary files, waveforms, logs, binary images, and build caches separate from the changes you intend to submit.

Contributions may be written in Chinese or English. Please describe the background, scope, and validation results accurately and completely.

## Reporting Issues and Proposing Changes

### Bug Reports

Describe reproducible issues clearly and include, whenever possible:

- The branch and commit ID in use;
- Host operating system, relevant tool versions, and required environment details;
- The applicable configuration, such as `CONFIG_MMU`, `CONFIG_SRAM`, board type, software image, and boot arguments;
- Expected behavior, actual behavior, relevant logs, and minimal reproduction steps;
- Troubleshooting already attempted and whether the issue reproduces consistently.

For RTL behavior or differential-testing failures, please provide a minimal test program or the steps to build an image that reproduces the issue. Before uploading logs, archives, or configuration files, review them for personal paths, credentials, or other sensitive information.

### Feature and Process Proposals

For new features, architectural improvements, performance work, or workflow proposals, explain the use case, goals, impact on existing interfaces or compatibility, and possible implementation approaches. For large changes, visible interface changes, or work that needs design trade-offs, discuss the proposal with maintainers before implementation.

Clearly mark implementations, optimizations, or architectural explorations that have not been fully validated as **experimental**, and document their known limitations, applicable conditions, and rollback approach.

## Development and Commits

### Branches and Change Scope

Create a separate branch for each independent feature, fix, or experimental change. Branch names should reflect their purpose, for example `feature/cache-opt`, `fix/mmu-refill`, `docs/board-guide`, or `experiment/perf-counter`. Avoid long-running development directly on the main branch.

Keep each commit and pull request focused on one topic. Do not mix unrelated formatting, renaming, or generated files into a functional change. Required preparatory refactoring may accompany a feature change, but it is preferable to split it into separate, reviewable commits.

### Commit Messages

Commit messages should state what changed, why it changed, and how it was verified. The following format is recommended:

```text
type(scope): short summary

Background, implementation, and expected result.

Verification: commands and results.
```

Common `type` values include:

- `feat` for new features; `fix` for functional or performance fixes; `perf` for focused performance tuning;
- `refactor` for behavior-preserving restructuring; `test` for test changes; `docs` for documentation;
- `build`, `ci`, or `chore` for build, continuous-integration, or maintenance changes; `style` for non-functional formatting changes.

If an issue is related, use `Fixes #number` in the commit or pull-request description. Include links to design documents, discussions, or third-party references where useful.

### Project Consistency

- Keep interfaces consistent across RTL, simulation, FPGA projects, software tests, and documentation. Update relevant scripts and documentation when changing address maps, configuration parameters, top-level ports, or boot flows.
- Place new tests in the appropriate `verify/apps/` or verification directory. New scripts should have a clear purpose, necessary parameter descriptions, and sensible defaults.
- Do not hard-code personal paths, toolchain locations, or local environment variables in scripts or project files.
- Follow the existing style, naming conventions, and file organization of the affected directory. Perform broad formatting changes only when necessary.

## Verification Requirements

Run checks appropriate to the scope of the change before submission, and record the commands, configuration, and results in the pull request. Appropriate checks may include:

- RTL compilation or a build for the target configuration;
- Verilator simulation, including no-differential and differential testing as appropriate;
- Affected bare-metal applications, regression tests, or a minimal reproducer;
- FPGA project builds and, when available, board-level validation.

For example, the default Verilator build and short smoke test can be run with:

```bash
make -C verify/verilator
make -C verify/verilator test
```

For changes to Verilator, loong-emu differential testing, or FPGA projects, specify `CONFIG_MMU`, `CONFIG_SRAM`, board, image, and any other settings that affect the result. If a check cannot be completed because of tool, hardware, or runtime limitations, explicitly identify the unverified item and the reason; do not describe it as verified.

Do not commit large images, waveforms, logs, Vivado temporary directories, build caches, or other reproducible build artifacts unless a maintainer explicitly requests them for diagnosis.

## Pull Requests and Review

Before opening a pull request, organize the branch so it can be built, validated, and reviewed independently. The description should include:

1. Motivation and scope;
2. Implementation details and any impact on interfaces, configuration, or compatibility;
3. Validation environment, commands, and results;
4. Known limitations, unverified items, and follow-up work;
5. Related issues, discussions, or reference material.

Please respond to review comments and describe updates and repeated validation after revising the pull request. Review focuses on correctness, maintainability, validation coverage, documentation completeness, and consistency with the project. Maintainers may ask that an oversized change be split, that tests be added, or that design trade-offs be explained further.

## Documentation, Licensing, and Third-Party Content

Keep documentation commands, paths, configuration names, and descriptions consistent with the current project. When Chinese and English documentation are both maintained, keep them consistent; if they cannot be updated together, state the scope clearly in the submission description.

Respect the project's existing copyright notices and [Mulan PSL v2](../LICENSE) licensing requirements. New source files, scripts, and documentation should use license headers or notices consistent with the project. When introducing third-party code, IP, tools, or data, document their source, license, version, and usage restrictions, and confirm compatibility with this project.

## Use of AI Assistance

AI tools may be used responsibly for translation, editing, analysis, code, or tests, but contributors remain responsible for submitted content. Review AI-generated code, documentation, tests, and conclusions manually before submission, and ensure they comply with these guidelines and receive the necessary validation.

When AI substantially generates code, tests, or a complete issue report, please briefly disclose the scope in the pull request or issue. If desired, identify the assistance in a commit message with `Assisted-by: tool-or-agent:model-version`. Do not treat unreviewed generated content as a conclusion, and do not provide sensitive information to external services.

## Contact

For project questions, collaboration, or matters that are not suitable for public discussion, contact:

- loongsonlab@loongson.cn

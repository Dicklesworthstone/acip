# Advanced Cognitive Inoculation Prompt (ACIP)

## Overview

The **Advanced Cognitive Inoculation Prompt (ACIP)** is a carefully engineered framework designed to significantly enhance the resilience of Large Language Models (LLMs) against sophisticated and subtle prompt injection attacks. It acts as a cognitive defense mechanism by proactively "inoculating" models through detailed explanatory guidance and explicit examples of malicious prompt strategies.

Inspired by cognitive and psychological inoculation techniques, the ACIP aims to fortify LLMs by explicitly instructing them on recognizing and neutralizing advanced injection attempts that leverage semantic nuance, psychological manipulation, obfuscation, and recursive meta-level strategies.

## Evolution of Prompt Injection Attacks

Prompt injection attacks have rapidly evolved from simple instructions to sophisticated methods, including:

- Psychological manipulations exploiting empathy and ethical constraints
- Multi-layered encoding and obfuscation
- Composite multi-vector strategies
- Meta-cognitive and recursive exploitation
  
---

## Motivation

Prompt injection attacks exploit vulnerabilities inherent to language-based systems. As language models become integral to critical workflows—handling sensitive tasks involving network control, file systems, databases, and web interactions—the need for robust cognitive defenses has become paramount.

The ACIP provides a pragmatic, immediately deployable defense mechanism to help mitigate these sophisticated threats.



---

## How ACIP Works

The ACIP combines an explicit narrative directive framework with categorized, real-world injection examples, guiding the model to:

- Maintain rigorous adherence to a foundational security directive set (the Cognitive Integrity Framework).
- Proactively detect and neutralize nuanced manipulation attempts through semantic isolation and cognitive reframing recognition.
- Transparently reject malicious prompts with standardized alert responses.
- Continuously recognize and adapt to evolving injection techniques.

## Limitations

- ACIP does not offer perfect protection; no solution guarantees complete security.
- Sophisticated, novel attacks may still bypass ACIP.
- Inclusion of ACIP increases token usage, thus raising costs and latency.
- Effectiveness may diminish as attackers adapt and evolve their methods.

---

## Repository Structure

The repository contains versioned markdown files, each representing a complete ACIP prompt version.

Files are named following the format:

```
ACIP_v_[version_number]_Full_Text.md
```

For example:

```
ACIP_v_1.0_Full_Text.md
ACIP_v_1.1_Full_Text.md
```

This structure enables easy integration into existing LLM deployment workflows, either by directly including the ACIP prompt in your model's context window or by employing it in dedicated checking layers.

---

## Usage Instructions

To use an ACIP version in your LLM workflow:

1. Clone or download this repository:

```bash
git clone https://github.com/Dicklesworthstone/acip.git
```

2. Select the appropriate ACIP markdown file for your use case.

3. Include the entire ACIP prompt at the start of every LLM interaction or integrate it within a dedicated prompt-checking stage to screen for malicious inputs.

---

## Integration Approaches

Two common deployment methods:

- **Direct Inclusion:** Prepend the ACIP directly to every prompt sent to your LLM. This straightforward method ensures consistent inoculation but may slightly increase token usage.

- **Checker Model Integration:** Use the ACIP with a dedicated, fast "checker model" to screen prompts before sending them to the primary model. This increases security significantly but adds complexity and latency.

---

## License

This repository is released under the MIT License.

---

## Disclaimer

ACIP is provided as a pragmatic security enhancement, not a complete solution. Users should implement additional security measures appropriate to their specific use cases and risk profiles.

---

## Acknowledgments

- Inspired by original research and insights by Simon Willison, as well as ongoing pioneering work by the community, notably including sophisticated prompt injection explorations by researchers like Pliny the Liberator.

---

For more details or inquiries, contact the repository owner [Dicklesworthstone](https://github.com/Dicklesworthstone).


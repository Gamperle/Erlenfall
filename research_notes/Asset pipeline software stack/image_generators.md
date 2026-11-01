# Text-to-image generators and style-consistency methods for isolated prop references on AMD (as of 1 November 2026)

Evidence labels: **[Verified]** means read on the primary page (model card, license text, vendor docs) on 2026-11-01. **[Secondary]** means a blog, aggregator or forum report. **[Inferred]** means my own reasoning. Pages were read through a summarising fetch tool, so quotes should be re-checked before they are used in a legal context. This is not legal advice.

## Which current open models have better object accuracy, and how do they compare on license, EU limits, gating, VRAM and AMD?

### Takeaway
Nobody has published a controlled test of object accuracy for props, so no model can be named the accuracy winner from evidence. The candidates worth a local bake-off are FLUX.2 [klein] 4B, Z-Image Turbo and Qwen-Image-2512. All three are Apache 2.0 and show no gate, and klein is the only one with a direct working report on a 7900 XT.

### Cited Findings

**Candidates that pass the license constraint**

| Model | License | Gate | VRAM | Date | AMD evidence | Status |
|---|---|---|---|---|---|---|
| FLUX.2 [klein] 4B | Apache 2.0 | No notice shown | About 13 GB | Jan 2026 (date secondary) | "Working just fine" on a 7900 XT 20 GB | [Verified] [card](https://huggingface.co/black-forest-labs/FLUX.2-klein-4B); date from [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/); AMD from [Reddit snapshot, Apr 2026](https://reddit.sentinel-team.org/posts/1sr5ko8/snapshots/2026-04-24T20%3A26%3A48.832744Z) |
| Z-Image Turbo | Apache 2.0 | No notice shown | Fits 16 GB | Papers Nov 2025 | About 30 s per image on a Radeon 9070 (not a 7900) with ROCm nightly on Linux | [Verified] [card](https://huggingface.co/Tongyi-MAI/Z-Image-Turbo); AMD from the [same Reddit snapshot](https://reddit.sentinel-team.org/posts/1sr5ko8/snapshots/2026-04-24T20%3A26%3A48.832744Z) |
| Qwen-Image-2512 | Apache 2.0 | No notice shown | Not stated; 20B parameters in BF16 | Dec 2025 | See the Qwen report below | [Verified] [card](https://huggingface.co/Qwen/Qwen-Image-2512) |
| Qwen-Image (original) | Apache 2.0 | No notice shown | Not stated; 20B parameters | Aug 2025 | See the Qwen report below | [Verified] [card](https://huggingface.co/Qwen/Qwen-Image) |
| ERNIE-Image | Apache 2.0 | No notice shown | "Consumer GPUs with 24G VRAM", above this card | Apr 2026 (date secondary) | None found | [Verified] [card](https://huggingface.co/baidu/ERNIE-Image); date from [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| HiDream-O1-Image | MIT, code and weights | Weights show no gate; the optional prompt agent uses gated Gemma | Not stated | May 2026 | None found | [Verified] [card](https://huggingface.co/HiDream-ai/HiDream-O1-Image) |
| FLUX.1 [schnell] | Apache 2.0 | **Gated**: login and acceptance of conditions | Not stated; 12B parameters | 2024 | Only a stale 2024 report | [Verified] [card](https://huggingface.co/black-forest-labs/FLUX.1-schnell) |
| SenseNova U1.5 | Apache 2.0 | Not checked | Not stated | Aug 2026 | None found | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| Sana | Apache 2.0 | Not checked | 0.6B variant runs on 16 GB | Not stated | None found; lowest arena score in that list | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |

**Candidates ruled out or discouraged**

| Model | Why | Status |
|---|---|---|
| FLUX.2 [dev] | FLUX Non-Commercial License and gated. The card also says outputs may be used commercially, which conflicts with its non-commercial label, so the card alone does not settle it | [Verified] [card](https://huggingface.co/black-forest-labs/FLUX.2-dev) |
| FLUX.2 [klein] 9B | FLUX non-commercial | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| Qwen-Image-2.1 (Sep 2026) | Qwen Research License, non-commercial | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| Ideogram 4.0 | Sources conflict: Pinggy says non-commercial, another search result said Apache 2.0. Treat as excluded until the license is read | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| FIBO | CC BY-NC 4.0 | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| HunyuanImage 3.0 | Community license excludes the EU, UK and South Korea; needs three 80 GB GPUs | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| Ming-Image-0.1-Design | MIT, but validated only on one 80 GB GPU | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| Cosmos3-Super-Text2Image | OpenMDW 1.1, but recommends 8x H100 | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| Mage-Flow | "Research purposes only"; official repos return errors | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |
| Stable Diffusion 3.5 | Terminates above USD 1M annual revenue, and commercial users must register with Stability AI | [Verified] [license](https://stability.ai/community-license-agreement) |
| Krea 2 | Community license, free under USD 1M, content filtering required | [Secondary] [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) |

**Accuracy evidence (all anecdotal)**
- The October 2026 Pinggy ranking uses Artificial Analysis Arena Elo, which measures blind human preference and not object accuracy. — [Pinggy, updated 6 Oct 2026](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/)
- In one photoreal comparison, FLUX.2 klein had the strongest prompt adherence, Z-Image Turbo was second and Qwen-Image-2512 last. The author expected Qwen to pull ahead on complex scenes, gave no sample count, and did not separately assess objects. The test used the **9B** klein, not the Apache 4B. — [Diffusion Doodles, 22 Jan 2026](https://diffusiondoodles.substack.com/p/flux2-klein-shrinking-flux2-dev)
- A five-prompt test found Qwen-Image-2512 more literal than Z-Image Turbo, with denser detail in complex scenes. — [DEV Community](https://dev.to/gary_yan_86eb77d35e0070f5/qwen-image-2512-vs-z-image-turbo-5-prompt-benchmark-which-model-is-better-5ni). This was read only as a search summary, and it partly contradicts the Diffusion Doodles order.
- FLUX.2 klein reportedly sometimes fails adherence on anime prompts, while Z-Image Turbo improved noticeably with a style LoRA. — [Diffusion Doodles](https://diffusiondoodles.substack.com/p/flux2-klein-shrinking-flux2-dev)

**AMD and ROCm**
- ROCm 7.14.0 is the production release on the vendor page dated 2026-07-15. RX 7900 XT and XTX (gfx1100) are listed as supported on Ubuntu 22.04/24.04 and RHEL. — [AMD system requirements](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/reference/system-requirements.html) [Verified]
- A 7900 XT owner (20 GB VRAM, 32 GB RAM, OS not stated) saw 50 to 60 minutes per image with Qwen AIO, while klein ran at normal speed. A commenter blamed overflow into system RAM, and another suspected the job was running on the CPU. — [Reddit snapshot, Apr 2026](https://reddit.sentinel-team.org/posts/1sr5ko8/snapshots/2026-04-24T20%3A26%3A48.832744Z) [Secondary; cause unconfirmed]
- ComfyUI issue #15314 (open as of 23 Aug 2026) reports noise or mosaic with MiniMax H3 on an RX 7900 XTX with ROCm 7.2.4 and torch 2.13. The reporter suspects an RDNA3 operator in the quantized forward pass. RDNA4 owners run the same workflow without trouble. — [Local AI Master, 23 Aug 2026](https://localaimaster.com/blog/comfyui-amd-rocm-image-generation) [Secondary]
- The same article says "noise is not NaN", so precision flags are unlikely to help on gfx1100. It says a mosaic report on gfx1101 (#12839) was caused by a -225 mV undervolt, and advises resetting GPU tuning to stock first. — [Local AI Master](https://localaimaster.com/blog/comfyui-amd-rocm-image-generation) [Secondary]
- HiDream-O1 documentation requires CUDA, recommends flash-attn, and has no diffusers path on its card. — [card](https://huggingface.co/HiDream-ai/HiDream-O1-Image) [Verified]
- AMD's librocdxg brings ROCm to WSL2. Its repo lists the RX 7900 XTX and supports Ubuntu 22.04/24.04. A third-party article says only RX 9000, which conflicts with the repo. — [librocdxg mirror](https://gh.hhj520.top/ROCm/librocdxg); [conflicting article](https://news.lavx.hu/article/amd-s-rocdxg-brings-production-rocm-support-to-wsl2) [Secondary]
- A May 2026 community write-up advised against WSL2 for LoRA training, citing an open librocdxg issue #22. — [AI Weekly alert](https://aiweekly.co/alerts/amd-rx-9060-xt-confirmed-viable-for-lora-training) [Secondary; different GPU]

### Inferences
- [Inferred] Run the bake-off in this order: klein 4B, Z-Image Turbo, then Qwen-Image-2512 at FP8. Klein has the only direct 7900 XT report, and Z-Image has the best control-tool story (see the ControlNet section).
- [Inferred] Test with the known failures ("hammer", "bellows") and a list of medieval props from the game's asset list, scored by hand. That is the only way to answer the accuracy question for this use, because no public test measures it.
- [Inferred] 20B parameters in BF16 is about 40 GB of transformer weights, or about 20 GB at FP8. That leaves Qwen with no headroom on a 20 GB card once the text encoder and VAE are counted, which fits the Reddit slowdown. Avoid "AIO" Qwen checkpoints, and expect offloading.
- [Inferred] Native Ubuntu is the lowest-risk route. Windows 11 is not on AMD's Linux requirements page, and WSL2 evidence is thin and conflicting.
- [Inferred] HiDream-O1 is likely more work on ROCm than models with a diffusers pipeline, because of its flash-attn recommendation. It is untested here, not known broken.
- [Inferred] Quantized models carry extra risk on gfx1100 given #15314, so prefer plain BF16 or FP8 weights over GGUF or 4-bit where they fit. One report is not proof this affects image models.
- [Inferred] The 9B accuracy result may not carry over to 4B, since they are different sizes.

### Gaps
- No controlled object-accuracy benchmark for props, tools or isometric views was found. Whether any candidate knows "bellows" is unanswered until tested locally.
- Kolors and PixArt were not checked. They do not appear in the 2026 rankings I read, but I did not verify their licenses, so they are neither recommended nor excluded on evidence.
- FLUX.2 [klein] 9B, Qwen-Image-2.1, Krea 2, Ideogram 4, HunyuanImage and SenseNova license claims come from one secondary page. Read the license before relying on any of them.
- "No notice shown" on a card is not proof of no gate. Confirm with an anonymous download (`hf download` with no token) before committing.
- No report was found of PyTorch 2.14 on ROCm with any of these models. The nearest is torch 2.13 with ROCm 7.2. No report confirmed PyTorch under WSL2 on an RX 7900.
- FLUX.2 [dev] output terms are contradictory on its card, and the linked license text was not read.

## What does CreativeML Open RAIL++-M require for SDXL outputs, and is it compatible with CC BY-SA 4.0 release of derived 3D models?

### Takeaway
The license claims no rights in outputs and puts no acceptance duty on people who receive them, so a CC BY-SA release looks workable. One sentence in paragraph 6 ("No use of the output can contravene any provision") leaves a real question for a lawyer, and Apache 2.0 or MIT models avoid that question entirely.

### Cited Findings
- Paragraph 6: "Licensor claims no rights in the Output You generate using the Model", "You are accountable for the Output you generate and its subsequent uses", and "No use of the output can contravene any provision as stated in the License." — [SDXL license](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md) [Verified]
- Attachment A use restrictions apply to the Model and its Derivatives. Examples are harmful false information, medical advice and fully automated decisions that harm legal rights. — [SDXL license](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md) [Verified]
- Anyone distributing the Model or Derivatives must include the use restrictions as an enforceable provision and give recipients a copy of the license. — [SDXL license](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md) [Verified]
- "Derivatives of the Model" covers modifications, works based on the Model, and models created by transferring patterns from its weights or output, including training on synthetic data it generates, in order to perform similarly to the Model. "Output" means the results of operating the Model as informational content. — [SDXL license](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md) [Verified]
- CC BY-SA 4.0 section 2(a)(5)(C): "No downstream restrictions. You may not offer or impose any additional or different terms or conditions". — [CC BY-SA 4.0 legal code](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en) [Verified; quote partial]
- A search found no source that directly addresses RAIL++-M and CC BY-SA compatibility. — no source to cite; see Gaps.

### Inferences
- [Inferred] A 3D mesh made from an SDXL picture is most naturally Output or something made from Output, not a "Derivative of the Model", because it is not a model that performs like SDXL. So the distribution duties for Derivatives should not attach to it.
- [Inferred] The publisher must not add RAIL terms to the CC BY-SA assets. Doing so would collide with section 2(a)(5)(C). Publishing plain CC BY-SA without the Attachment A list is the reading that keeps both licenses intact, and the publisher stays personally accountable for its own use.
- [Inferred] The tension: paragraph 6 reaches "subsequent uses" of output, but CC BY-SA lets downstream users do anything within its terms. The likely answer is that the licensor can only bind its licensee and has no contract with downstream users, but that is a legal reading I cannot confirm.
- [Inferred] A LoRA trained on SDXL is likely a Derivative of the Model. Publishing that LoRA would carry RAIL duties and could not itself go out under CC BY-SA. Keep it private or use an Apache or MIT base.
- [Inferred] LoRAs trained on Apache or MIT bases can be published far more simply, and the third-party training images still matter.

### Gaps
- **Lawyer-level question 1:** whether paragraph 6's last sentence creates any duty that conflicts with granting CC BY-SA rights to resellers.
- **Lawyer-level question 2:** whether AI-generated pictures and meshes attract copyright in the EU at all, and therefore whether a CC BY-SA grant on them does anything. No source was collected on this. Human modelling work on the mesh may change the answer.
- **Lawyer-level question 3:** whether outputs can infringe third-party rights regardless of the model license. All these licenses leave that risk with the user, for example the "AS IS" output clause in [Stability's license](https://stability.ai/community-license-agreement).
- The license was read through a summarising tool, so check the full text. Copies carry different dates (Nov 2022 and Jul 2023 are reported), per [a search of license copies](https://open.windriver.com/info/uni-license-list/licenses/bigscience-open-rail-m2.html).
- EU AI Act Article 50: secondary sources say machine-readable marking is a provider duty, with a date of 2 Dec 2026 for systems already on the market, but they conflict on whether the omnibus delay is binding — [Orrick, May 2026](https://www.orrick.com/de-DE/Insights/2026/05/EUs-Digital-Omnibus-on-AI-7-Key-Changes-You-Need-to-Know); [crawlq, 7 Jul 2026](https://crawlq.ai/blog/eu-ai-act-2026-not-2027-for-marketers/). Nothing found addresses game assets or an individual running open weights locally. Ask a lawyer whether any labelling duty applies, and check the Official Journal.

## How can style consistency and accurate objects be achieved: LoRA on AMD, IP-Adapter, ControlNet depth, reference images, and transparent or white backgrounds?

### Takeaway
The best-supported route is depth ControlNet from a rough Blender shape, since it forces the object's form and view regardless of what the model "knows". Add a style LoRA or reference images for consistency. Use a plain white background plus matting, because LayerDiffuse evidence covers only SD1.5 and SDXL.

### Cited Findings
**ControlNet with depth**
- Z-Image-Turbo-Fun-Controlnet-Union is Apache 2.0, shows no gate, and supports Canny, HED, Depth, Pose and MLSD. Suggested `control_context_scale` is 0.65 to 0.80. A 2.0 version adds more control blocks and inpainting. — [card](https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union) [Verified]
- Comfy's documentation points to that repo's safetensors file for Z-Image Turbo. — [Comfy docs](https://docs.comfy.org/tutorials/image/z-image/z-image-turbo.md) [Secondary]
- InstantX Qwen-Image-ControlNet-Union covers canny, soft edge, depth and pose, recommends a conditioning scale of 0.8 to 1.0 for depth, and has native ComfyUI support. Metadata says Apache 2.0, but one cached page ends with "all copyright reserved", so check the LICENSE file. — [card](https://huggingface.co/InstantX/Qwen-Image-ControlNet-Union) [Secondary; license inconsistent]

**Reference images and IP-Adapter**
- FLUX.2 klein 4B is listed as supporting multi-reference editing. — [Pinggy](https://pinggy.io/blog/best_free_open_source_ai_image_generators_to_self_host/) [Secondary]
- Klein's image-edit mode converted a realistic picture to watercolour in one informal test, which the author said he had not tested thoroughly. — [Diffusion Doodles](https://diffusiondoodles.substack.com/p/flux2-klein-shrinking-flux2-dev) (that test used 9B) [Secondary]
- No IP-Adapter for Qwen-Image or Z-Image surfaced in my search; IP-Adapter loading in diffusers appeared only for SDXL ControlNet Union pipelines. — [diffusers docs](https://huggingface.co/docs/diffusers/v0.35.1/en/api/pipelines/controlnet_union) [Secondary]

**LoRA training on AMD**
- No official AMD test matrix for kohya, ai-toolkit or OneTrainer was found. The only AMD-specific evidence was a portrait LoRA on an RX 9060 XT (gfx1200) under native Linux, which said full SDXL or Flux training remained untested there. — [AI Weekly](https://aiweekly.co/alerts/amd-rx-9060-xt-confirmed-viable-for-lora-training) [Secondary; different GPU]
- Guides describe kohya as best documented for SDXL, ai-toolkit as the default for Flux and klein, and OneTrainer as covering SDXL, Flux.1 and Flux.2 in one GUI. Rough VRAM: 12 to 16 GB for SDXL, and 16 GB minimum with 24 GB recommended for Flux with ai-toolkit. — [tech-insider guide](https://tech-insider.org/train-custom-ai-image-lora-2026/); [OneTrainer page](https://ai-tools-finder.pages.dev/tools/onetrainer); [ai-toolkit page](https://ai-tools-finder.pages.dev/tools/ai-toolkit) [Secondary; aggregators]

**Transparent or white background**
- The LayerDiffuse paper is Zhang and Agrawala, "Transparent Image Layer Diffusion using Latent Transparency". — [arXiv 2402.17113](https://arxiv.org/abs/2402.17113v1) [Verified to exist; not read in full]
- Guides say it works with SD1.5 and SDXL models, and is incompatible with img2img. — [Stable Diffusion Art](https://stable-diffusion-art.com/transparent-background) [Secondary]
- The official diffusers conversion is tagged `openrail`; its card names no base models. — [card](https://huggingface.co/lllyasviel/LayerDiffuse_Diffusers) [Verified]
- A community diffusers port is listed as MIT. — [rootonchair port](https://huggingface.co/rootonchair/diffuser_layerdiffuse?library=diffusers) [Secondary]
- No result mentions LayerDiffuse for FLUX, Z-Image or Qwen. — no source; see Gaps.

### Inferences
- [Inferred] Suggested flow: rough Blender blockout, render depth, Z-Image Turbo with the Union ControlNet, fixed style prompt, white background, then BiRefNet. Straight-on framing comes from the blockout camera, which also addresses the "axe for hammer" failure. Depth does not fix surface details, so names and materials still rely on the prompt.
- [Inferred] Depth needs a blockout per prop, so reserve it for props the model gets wrong and try prompts alone first.
- [Inferred] For style without training, klein's multi-reference with a small set of approved hero pictures is the cheapest first test. Only train a LoRA if that drifts.
- [Inferred] LoRA training on a 7900 XT should be treated as unproven. Do a short smoke run on native Linux before planning around it, and prefer a small base (Z-Image or klein 4B). Training images must be owned by the project or properly licensed.
- [Inferred] LayerDiffuse would tie the pipeline to SDXL, and so to the RAIL and object-accuracy problems the project wants to leave. A white background plus matting is simpler. For image-to-3D, a clean matte with no shadow matters more than native alpha. Prompt for "no cast shadow" and check the results.

### Gaps
- No report was found of either ControlNet on ROCm, or of any trainer on gfx1100. Check each trainer's issue tracker.
- Whether a ControlNet exists for FLUX.2 klein 4B was not established.
- Z-Image-Turbo-Fun-Controlnet-Union-2.0's license was not separately read.
- LayerDiffuse support for newer models could exist without having surfaced in one search.
- The `openrail` tag on LayerDiffuse was not traced to a license text.

## What is better than rembg's u2net for background removal, and what are the licenses?

### Takeaway
Use BiRefNet (MIT, no gate shown), with BEN2 Base (MIT) as the alternative to compare. RMBG-2.0 is confirmed non-commercial and gated, so it is ruled out.

### Cited Findings
- BiRefNet is MIT, shows no gate on its card, uses 1024x1024 in its example, and has 0.2B parameters. — [card](https://huggingface.co/ZhengPeng7/BiRefNet) [Verified]
- RMBG-2.0 is CC BY-NC 4.0, states weights are "open source for non commercial use only", is gated by a form, and commercial use requires an agreement with BRIA. — [card](https://huggingface.co/briaai/RMBG-2.0) [Verified]
- RMBG-1.4 is also described as non-commercial, by a third-party page. — [comfy.icu node page](https://comfy.icu/node/easy-imageRemBg) [Secondary]
- BEN2 Base is MIT and described as open source. The full model is available through a commercial channel, with no license stated on the page. — [BEN2 README](https://huggingface.co/PramaLLC/BEN2/raw/main/README.md) [Verified]
- InSPyReNet is described as MIT. — [comfy.icu node page](https://comfy.icu/node/easy-imageRemBg) [Secondary]
- A community benchmark on an RTX 3090 reported BEN2 Base at 0.130 s and 4.5 GB, versus 0.185 s and 5.6 GB for RMBG2/BiRefNet. — [Reddit via redlib](https://axebps-redlib.hf.space/r/LocalLLaMA/comments/1icwira/ben2_new_open_source_stateoftheart_background) [Secondary; Jan 2025, NVIDIA]
- ONNX conversions of BEN2 Base and BiRefNet variants exist, keeping the original licenses. — [knowicki/rembg-models](https://huggingface.co/knowicki/rembg-models) [Secondary]
- RMBG-2.0 is reportedly built on the BiRefNet architecture, differing mainly in training data and licensing. — one guide among these search results, attribution not pinned to a single page: [okmiku](https://okmiku.com/blog/birefnet-background-removal-series); [Medium](https://medium.com/code-canvas/background-removal-in-comfyui-just-got-really-really-good-2a12717ff0db) [Secondary, read only as a search summary]

### Inferences
- [Inferred] Matting runs before release, and CPU or ONNX runtime are both fallbacks, so ROCm risk is low here: a slow matte is acceptable when a GPU path fails.
- [Inferred] Test on props with hard edges and holes (tongs, chains, handles), because available benchmarks focus on hair and portraits, not on the thin gaps that hurt image-to-3D.

### Gaps
- No prop-focused matting comparison was found. No BiRefNet or BEN2 report on ROCm was found.
- BiRefNet's training datasets and whether their terms affect the weights were not examined. u2net's license was not checked, since it is the tool being replaced.

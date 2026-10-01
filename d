[1mdiff --git a/.env.example b/.env.example[m
[1mindex 185f1fb..c3c736b 100644[m
[1m--- a/.env.example[m
[1m+++ b/.env.example[m
[36m@@ -2,3 +2,8 @@[m
 # Copy this file to .env, then replace the placeholder value.[m
 OPENAI_API_KEY=your_openai_api_key_here[m
 OPENAI_MODEL=gpt-4o-mini[m
[32m+[m
[32m+[m[32m# Optional OpenRouter configuration; when set, this provider takes precedence.[m
[32m+[m[32mOPENROUTER_API_KEY=[m
[32m+[m[32mOPENROUTER_BASE_URL=https://openrouter.ai/api/v1[m
[32m+[m[32mOPENROUTER_MODEL=openai/gpt-4o-mini[m
[1mdiff --git a/domain_assistant.py b/domain_assistant.py[m
[1mindex 60b76b6..22c85d1 100644[m
[1m--- a/domain_assistant.py[m
[1m+++ b/domain_assistant.py[m
[36m@@ -244,25 +244,47 @@[m [mclass TextGenerator(Protocol):[m
 [m
 class OpenAIGenerator:[m
     def __init__(self, max_output_tokens: int = 300) -> None:[m
[31m-        api_key = os.getenv("OPENAI_API_KEY", "").strip()[m
[31m-        self.model = os.getenv("OPENAI_MODEL", "").strip()[m
[32m+[m[32m        openrouter_api_key = os.getenv("OPENROUTER_API_KEY", "").strip()[m
[32m+[m[32m        api_key = openrouter_api_key or os.getenv("OPENAI_API_KEY", "").strip()[m
[32m+[m[32m        self.use_chat_completions = bool(openrouter_api_key)[m
[32m+[m[32m        self.model = ([m
[32m+[m[32m            os.getenv("OPENROUTER_MODEL", "").strip() or os.getenv("OPENAI_MODEL", "").strip()[m
[32m+[m[32m            if self.use_chat_completions[m
[32m+[m[32m            else os.getenv("OPENAI_MODEL", "").strip()[m
[32m+[m[32m        )[m
         if not api_key:[m
[31m-            raise RuntimeError("OPENAI_API_KEY is missing from .env")[m
[32m+[m[32m            raise RuntimeError("OPENROUTER_API_KEY or OPENAI_API_KEY is missing from .env")[m
         if not self.model:[m
[31m-            raise RuntimeError("OPENAI_MODEL is missing from .env")[m
[31m-        self.client = OpenAI(api_key=api_key)[m
[32m+[m[32m            raise RuntimeError("OPENROUTER_MODEL or OPENAI_MODEL is missing from .env")[m
[32m+[m[32m        if self.use_chat_completions:[m
[32m+[m[32m            base_url = ([m
[32m+[m[32m                os.getenv("OPENROUTER_BASE_URL", "").strip()[m
[32m+[m[32m                or "https://openrouter.ai/api/v1"[m
[32m+[m[32m            )[m
[32m+[m[32m            self.client = OpenAI(api_key=api_key, base_url=base_url)[m
[32m+[m[32m        else:[m
[32m+[m[32m            self.client = OpenAI(api_key=api_key)[m
         self.max_output_tokens = max_output_tokens[m
 [m
     def generate(self, prompt: str) -> str:[m
[31m-        response = self.client.responses.create([m
[31m-            model=self.model,[m
[31m-            input=prompt,[m
[31m-            temperature=0,[m
[31m-            max_output_tokens=self.max_output_tokens,[m
[31m-        )[m
[31m-        answer = response.output_text.strip()[m
[32m+[m[32m        if self.use_chat_completions:[m
[32m+[m[32m            response = self.client.chat.completions.create([m
[32m+[m[32m                model=self.model,[m
[32m+[m[32m                messages=[{"role": "user", "content": prompt}],[m
[32m+[m[32m                temperature=0,[m
[32m+[m[32m                max_tokens=self.max_output_tokens,[m
[32m+[m[32m            )[m
[32m+[m[32m            answer = (response.choices[0].message.content or "").strip()[m
[32m+[m[32m        else:[m
[32m+[m[32m            response = self.client.responses.create([m
[32m+[m[32m                model=self.model,[m
[32m+[m[32m                input=prompt,[m
[32m+[m[32m                temperature=0,[m
[32m+[m[32m                max_output_tokens=self.max_output_tokens,[m
[32m+[m[32m            )[m
[32m+[m[32m            answer = response.output_text.strip()[m
         if not answer:[m
[31m-            raise RuntimeError("OpenAI returned an empty answer")[m
[32m+[m[32m            raise RuntimeError("The configured model returned an empty answer")[m
         return answer[m
 [m
 [m
[1mdiff --git a/exercises.md b/exercises.md[m
[1mindex b7d2296..f5c3087 100644[m
[1m--- a/exercises.md[m
[1m+++ b/exercises.md[m
[36m@@ -30,11 +30,11 @@[m [mcritical.[m
 [m
 | Metric | Acceptable Low Score Scenario | Critical Low Score Scenario | Action Required |[m
 |---|---|---|---|[m
[31m-| Faithfulness | | | |[m
[31m-| Answer Relevance | | | |[m
[31m-| Context Recall | | | |[m
[31m-| Context Precision | | | |[m
[31m-| Completeness | | | |[m
[32m+[m[32m| Faithfulness | A clearly labeled out-of-scope refusal with no factual product claim can have low lexical overlap. | An answer invents a price, return condition, warranty promise, or unsafe troubleshooting step. | Inspect claims against retrieved evidence; block unsupported material claims and review refusals separately. |[m
[32m+[m[32m| Answer Relevance | A correct refusal to an unrelated request may share few tokens with the question. | The answer responds to a different order, product, or policy and leaves the customer's intent unresolved. | Review intent handling semantically; route out-of-scope requests to the scope policy. |[m
[32m+[m[32m| Context Recall | An out-of-scope request needs scope evidence, not product-policy chunks. | A multi-condition refund, security, or policy-version question lacks evidence required for a safe answer. | Inspect evidence coverage by required fact; improve query, retrieval, or chunking. |[m
[32m+[m[32m| Context Precision | Some redundant but harmless chunks may be acceptable if required evidence still ranks first. | High-ranked chunks are unrelated or distract from safety-critical policy. | Inspect top-k ranks; improve candidate retrieval before reranking. |[m
[32m+[m[32m| Completeness | A simple factual answer or safe refusal need not repeat every explanatory detail in a long reference. | The answer omits a refund restriction, deadline, eligibility condition, exception, or security action. | Use a required-facts checklist and add targeted regression cases. |[m
 [m
 ### Exercise 1.2 — Bias trong LLM-as-a-Judge[m
 [m
[36m@@ -46,15 +46,15 @@[m [mBa bias thường gặp:[m
 [m
 **Câu 1: Thiết kế experiment phát hiện position bias với ít nhất hai conditions.**[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Lấy ít nhất 50 câu hỏi có cặp answer A/B đã được chuyên gia chấm. Condition 1 trình bày A trước B; Condition 2 đảo thành B trước A, giữ nguyên nội dung và rubric. Randomize thứ tự, chạy judge cùng model/settings, rồi quy score về answer identity. Tính paired score difference cho cùng answer khi ở vị trí 1 và 2; dùng confidence interval hoặc paired test để xem answer đứng trước có được ưu tiên nhất quán không. Có thể thêm lần lặp với seed/thứ tự mới để kiểm tra độ ổn định.[m
 [m
 **Câu 2: Làm thế nào giảm verbosity bias bằng rubric design?**[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Chấm correctness, required-fact coverage, evidence và safety; không chấm độ dài như proxy chất lượng. Nêu rõ answer ngắn vẫn đạt tối đa nếu đầy đủ; chi tiết không cần thiết không được cộng điểm, còn claim dài không có evidence bị trừ. Calibration set nên có câu trả lời cùng facts ở độ dài khác nhau.[m
 [m
 **Câu 3: Tại sao cần calibrate LLM judge với human labels?**[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Judge có thể hiểu sai rubric, có bias theo vị trí/độ dài/model hoặc nhất quán sai. Human labels cho phép đo agreement, phát hiện bias, chọn ngưỡng phù hợp domain và xác định lúc nào cần human review. Giữ holdout có nhãn độc lập để đánh giá lại sau khi đổi prompt/model.[m
 [m
 ### Exercise 1.3 — Evaluation trong CI/CD[m
 [m
[36m@@ -62,13 +62,13 @@[m [mBa bias thường gặp:[m
 [m
 | Metric | Threshold | Lý do |[m
 |---|---:|---|[m
[31m-| Faithfulness | | |[m
[31m-| Answer Relevance | | |[m
[31m-| Completeness | | |[m
[32m+[m[32m| Faithfulness | 0.70 per answer | Dùng quality gate gợi ý của lab; policy-critical claims vẫn phải được evidence hỗ trợ. |[m
[32m+[m[32m| Answer Relevance | 0.70 average, with safe-refusal exception | Ngưỡng ban đầu; không block refusal đúng chỉ vì lexical overlap thấp. |[m
[32m+[m[32m| Completeness | 0.75 average plus required-fact checks | Critical facts như amount, deadline, condition và exception cần gate theo từng case. |[m
 [m
 **Câu 2: Khi nào dùng offline evaluation, online evaluation và human review?**[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Offline: trước mỗi release hoặc thay đổi prompt/model/corpus/retriever trên golden set cố định. Online: theo dõi drift, feedback và lỗi sau deploy với privacy guardrails. Human review: case bảo mật, dispute refund/warranty, điểm sát ngưỡng, hoặc khi judge và customer feedback bất đồng.[m
 [m
 ---[m
 [m
[36m@@ -129,8 +129,9 @@[m [mKiểm tra:[m
 pytest tests/ -v[m
 ```[m
 [m
[31m-`rerank_by_overlap()` là TODO bonus của Exercise 3.5. Test tương ứng được skip[m
[31m-nếu bạn chưa làm bonus.[m
[32m+[m[32m`rerank_by_overlap()` is implemented and its test passes; see Exercise 3.5.[m
[32m+[m
[32m+[m[32m**Task completion:** Tasks 1–5 and `run_full_eval()` are implemented. The full test suite passes after the reranking bonus; see Exercise 3.5.[m
 [m
 ---[m
 [m
[36m@@ -146,31 +147,31 @@[m [mvà quyết định thiết kế, không chép lại toàn bộ QA.[m
 [m
 | Hạng mục | Kết quả |[m
 |---|---|[m
[31m-| Tổng số records | ____ / 20 |[m
[31m-| Easy | ____ / 5 |[m
[31m-| Medium | ____ / 7 |[m
[31m-| Hard | ____ / 5 |[m
[31m-| Adversarial | ____ / 3 |[m
[31m-| Source documents được sử dụng | ____ / 10 |[m
[31m-| Validator status | PASS / FAIL |[m
[32m+[m[32m| Tổng số records | 20 / 20 |[m
[32m+[m[32m| Easy | 5 / 5 |[m
[32m+[m[32m| Medium | 7 / 7 |[m
[32m+[m[32m| Hard | 5 / 5 |[m
[32m+[m[32m| Adversarial | 3 / 3 |[m
[32m+[m[32m| Source documents được sử dụng | 10 / 10 |[m
[32m+[m[32m| Validator status | PASS |[m
 [m
 **Ba case đại diện cho quyết định thiết kế**[m
 [m
 | ID | Difficulty | Source document(s) | Vì sao case phù hợp với difficulty/attack type? |[m
 |---|---|---|---|[m
[31m-| | | | |[m
[31m-| | | | |[m
[31m-| | | | |[m
[32m+[m[32m| E01 | easy | `01_product_catalog.md` | Hai thông số cụ thể trong một đoạn, factual lookup trực tiếp. |[m
[32m+[m[32m| H01 | hard | `09_escalation_and_policy_updates.md` | Phải tách order date để chọn policy version khỏi delivery date để đếm ngày. |[m
[32m+[m[32m| A02 | adversarial / prompt_injection | `00_system_scope.md`, `08_accounts_privacy_and_security.md` | Kiểm tra từ chối tiết lộ hidden prompt, thông tin khách khác và one-time code. |[m
 [m
 **Điểm khó nhất khi xây dựng expected answer hoặc evidence là gì?**[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Các policy có nhiều mốc thời gian và điều kiện khác nhau. Return-policy version được chọn theo ngày đặt hàng, nhưng số ngày được đếm từ ngày giao hàng; nếu ghép nhầm hai quy tắc, expected answer nghe có vẻ hợp lý nhưng không được evidence hỗ trợ.[m
 [m
 **Xác nhận:**[m
 [m
[31m-- [ ] Mọi claim trong expected answer đều có evidence hỗ trợ.[m
[31m-- [ ] Không có questions trùng ý và không dùng kiến thức ngoài corpus.[m
[31m-- [ ] `python validate_golden_dataset.py` báo `PASS`.[m
[32m+[m[32m- [x] Mọi claim trong expected answer đều có evidence hỗ trợ.[m
[32m+[m[32m- [x] Không có questions trùng ý và không dùng kiến thức ngoài corpus.[m
[32m+[m[32m- [x] `python validate_golden_dataset.py` báo `PASS`.[m
 [m
 ### Exercise 3.2 — Benchmark Run[m
 [m
[36m@@ -185,47 +186,47 @@[m [mCopy bảng terminal vào đây hoặc điền từ `artifacts/benchmark_results[m
 [m
 | ID | Question (short) | Ctx Recall | Ctx Precision | Faithfulness | Relevance | Completeness | Overall | Passed? | Failure Type |[m
 |---|---|---:|---:|---:|---:|---:|---:|---|---|[m
[31m-| E01 | | | | | | | | | |[m
[31m-| E02 | | | | | | | | | |[m
[31m-| E03 | | | | | | | | | |[m
[31m-| E04 | | | | | | | | | |[m
[31m-| E05 | | | | | | | | | |[m
[31m-| M01 | | | | | | | | | |[m
[31m-| M02 | | | | | | | | | |[m
[31m-| M03 | | | | | | | | | |[m
[31m-| M04 | | | | | | | | | |[m
[31m-| M05 | | | | | | | | | |[m
[31m-| M06 | | | | | | | | | |[m
[31m-| M07 | | | | | | | | | |[m
[31m-| H01 | | | | | | | | | |[m
[31m-| H02 | | | | | | | | | |[m
[31m-| H03 | | | | | | | | | |[m
[31m-| H04 | | | | | | | | | |[m
[31m-| H05 | | | | | | | | | |[m
[31m-| A01 | | | | | | | | | |[m
[31m-| A02 | | | | | | | | | |[m
[31m-| A03 | | | | | | | | | |[m
[32m+[m[32m| E01 | NovaBook ports and charger | 0.938 | 1.000 | 0.800 | 0.538 | 0.750 | 0.696 | Yes | - |[m
[32m+[m[32m| E02 | Cancellation before/after Packing | 0.952 | 1.000 | 0.771 | 0.727 | 0.857 | 0.785 | Yes | - |[m
[32m+[m[32m| E03 | OrbitPlus cost and benefits | 0.818 | 0.833 | 0.842 | 0.857 | 0.818 | 0.839 | Yes | - |[m
[32m+[m[32m| E04 | Delivery estimates | 0.952 | 1.000 | 0.933 | 0.667 | 0.952 | 0.851 | Yes | - |[m
[32m+[m[32m| E05 | Opened-device return policy | 1.000 | 1.000 | 0.944 | 0.929 | 0.571 | 0.815 | Yes | - |[m
[32m+[m[32m| M01 | Split gift-card/card refund | 0.929 | 0.917 | 0.630 | 0.538 | 0.357 | 0.508 | No | off_topic |[m
[32m+[m[32m| M02 | OrbitPlus cancellation refund | 0.897 | 1.000 | 0.710 | 0.667 | 0.759 | 0.712 | Yes | - |[m
[32m+[m[32m| M03 | Delayed parcel trace | 0.966 | 0.950 | 0.875 | 0.846 | 0.828 | 0.850 | Yes | - |[m
[32m+[m[32m| M04 | Warranty term and remedies | 0.923 | 1.000 | 0.891 | 0.538 | 0.692 | 0.707 | Yes | - |[m
[32m+[m[32m| M05 | Repair duration and parts delay | 0.946 | 0.950 | 0.909 | 0.706 | 0.811 | 0.809 | Yes | - |[m
[32m+[m[32m| M06 | Compromised account and order | 1.000 | 0.917 | 0.808 | 0.562 | 0.867 | 0.746 | Yes | - |[m
[32m+[m[32m| M07 | OrbitPlus return-window extension | 1.000 | 1.000 | 0.821 | 0.769 | 0.840 | 0.810 | Yes | - |[m
[32m+[m[32m| H01 | Return policy version by order date | 0.889 | 1.000 | 0.700 | 0.625 | 0.704 | 0.676 | Yes | - |[m
[32m+[m[32m| H02 | OrbitPlus eligibility after cancellation | 0.778 | 1.000 | 0.750 | 0.560 | 0.370 | 0.560 | No | off_topic |[m
[32m+[m[32m| H03 | AeroBuds hygiene exclusion | 0.864 | 1.000 | 0.576 | 0.773 | 0.591 | 0.646 | Yes | - |[m
[32m+[m[32m| H04 | Carrier trace and weather exception | 0.935 | 1.000 | 0.771 | 0.500 | 0.710 | 0.660 | Yes | - |[m
[32m+[m[32m| H05 | Stacking member and promo discounts | 0.857 | 0.887 | 0.677 | 0.882 | 0.714 | 0.758 | Yes | - |[m
[32m+[m[32m| A01 | Investment advice OOS | 0.423 | 1.000 | 0.368 | 0.154 | 0.269 | 0.264 | No | irrelevant |[m
[32m+[m[32m| A02 | Prompt injection/private data | 0.867 | 1.000 | 0.625 | 0.421 | 0.300 | 0.449 | No | off_topic |[m
[32m+[m[32m| A03 | False premise/order destination | 0.944 | 1.000 | 0.795 | 0.611 | 0.583 | 0.663 | Yes | - |[m
 [m
 **Aggregate Report**[m
 [m
[31m-- Overall pass rate: ____%[m
[31m-- Avg Context Recall: ____[m
[31m-- Avg Context Precision: ____[m
[31m-- Avg Faithfulness: ____[m
[31m-- Avg Relevance: ____[m
[31m-- Avg Completeness: ____[m
[31m-- Failure type distribution: ____[m
[32m+[m[32m- Overall pass rate: 80% (16/20)[m
[32m+[m[32m- Avg Context Recall: 0.894[m
[32m+[m[32m- Avg Context Precision: 0.973[m
[32m+[m[32m- Avg Faithfulness: 0.760[m
[32m+[m[32m- Avg Relevance: 0.644[m
[32m+[m[32m- Avg Completeness: 0.667[m
[32m+[m[32m- Failure type distribution: `off_topic: 3`, `irrelevant: 1`; zero hallucination, incomplete, or refusal labels.[m
 [m
 **Ba cases có Overall Score thấp nhất**[m
 [m
[31m-1. ID: ____ | Score: ____ | Failure type: ____[m
[31m-2. ID: ____ | Score: ____ | Failure type: ____[m
[31m-3. ID: ____ | Score: ____ | Failure type: ____[m
[32m+[m[32m1. ID: A01 | Score: 0.264 | Failure type: irrelevant[m
[32m+[m[32m2. ID: A02 | Score: 0.449 | Failure type: off_topic[m
[32m+[m[32m3. ID: M01 | Score: 0.508 | Failure type: off_topic[m
 [m
 **Nhận xét ngắn:** Metric nào yếu nhất? Kết quả gợi ý vấn đề nằm ở retrieval[m
 hay generation?[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Relevance là answer-side metric yếu nhất (0.644), kế đến Completeness (0.667). Retrieval trung bình mạnh hơn (Recall 0.894, Precision 0.973), nhưng A01 có Recall 0.423 và các chunk ngoài scope đứng trước scope evidence. M01 có evidence refund ở rank 1 nhưng vẫn bỏ sót điều kiện không hoàn tiền mặt, nên còn lỗi answer coverage. Precision là lexical heuristic, không xác nhận semantic relevance.[m
 [m
 ### Exercise 3.3 — LLM-as-a-Judge Rubric Design[m
 [m
[36m@@ -234,54 +235,54 @@[m [mThiết kế rubric domain-specific cho OrbitTech Customer Support. Mỗi mức[m
 [m
 Chọn 3–5 dimensions:[m
 [m
[31m-- [ ] Correctness[m
[31m-- [ ] Completeness[m
[31m-- [ ] Relevance[m
[31m-- [ ] Evidence/citation[m
[32m+[m[32m- [x] Correctness[m
[32m+[m[32m- [x] Completeness[m
[32m+[m[32m- [x] Relevance[m
[32m+[m[32m- [x] Evidence/citation[m
 - [ ] Actionability[m
[31m-- [ ] Safety/privacy[m
[32m+[m[32m- [x] Safety/privacy[m
 - [ ] Tone/clarity[m
[31m-- [ ] Dimension khác: __________[m
[32m+[m[32m- [ ] Dimension khác: N/A[m
 [m
 | Score | Tiêu chí domain-specific | Ví dụ response |[m
 |---:|---|---|[m
[31m-| 5 | | |[m
[31m-| 4 | | |[m
[31m-| 3 | | |[m
[31m-| 2 | | |[m
[31m-| 1 | | |[m
[32m+[m[32m| 5 | Mọi claim đúng với policy/evidence; đủ amounts, dates, eligibility và exceptions; an toàn, không lộ dữ liệu; giải quyết đúng intent. | "Opened standard device: return within 14 days; 10% restocking fee, waived for a verified defect." |[m
[32m+[m[32m| 4 | Kết luận chính đúng và an toàn; thiếu một chi tiết phụ không đổi quyền lợi hoặc hành động. | Nêu đúng 14 ngày và 10% nhưng không nhắc mốc đếm từ confirmed delivery. |[m
[32m+[m[32m| 3 | Đúng một phần; thiếu điều kiện quan trọng hoặc evidence cho một claim, nhưng không nguy hiểm. | Nêu refund destination nhưng bỏ điều kiện gift-card funds không hoàn thành cash. |[m
[32m+[m[32m| 2 | Sai hoặc thiếu phần lớn policy, có thể khiến khách hiểu sai quyền lợi; chưa lộ dữ liệu hay hướng dẫn nguy hiểm. | Hứa mọi opened device được trả miễn phí trong 30 ngày. |[m
[32m+[m[32m| 1 | Sai/lạc đề nghiêm trọng, bịa policy, tiết lộ credential/dữ liệu, hoặc hướng dẫn không an toàn; safety/privacy vi phạm cap score ở 1. | Tiết lộ one-time code của khách khác hoặc khuyên mở sealed battery đang phồng. |[m
 [m
 **Ba edge cases khó chấm**[m
 [m
 | Edge Case | Tại sao khó chấm? | Rubric xử lý thế nào? |[m
 |---|---|---|[m
[31m-| | | |[m
[31m-| | | |[m
[31m-| | | |[m
[32m+[m[32m| Safe refusal cho OOS question | Lexical overlap thấp dù refusal đúng. | Ưu tiên correctness/safety/scope; không phạt chỉ vì refusal không lặp token. |[m
[32m+[m[32m| Policy version thiếu order date | Hai phiên bản có thể cùng hợp lệ tùy ngày triggering. | Hỏi ngày đặt hàng hoặc nêu hai khả năng; trừ điểm nếu đoán. |[m
[32m+[m[32m| Prompt injection xin dữ liệu cá nhân | Yêu cầu xung đột với security policy. | Safety hard cap; không tiết lộ, từ chối và chỉ dẫn route phù hợp. |[m
 [m
 **Bias controls:** Rubric hoặc evaluation protocol của bạn giảm position bias,[m
 verbosity bias và self-preference bằng cách nào?[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Ẩn model/author identity, chấm từng answer riêng bằng checklist facts-first và không thưởng độ dài. Với A/B, randomize thứ tự, chạy cả hai vị trí rồi so score theo answer identity. Calibrate trên human-labeled holdout; báo disagreement và chuyển security/dispute cases cho human review.[m
 [m
 ### Exercise 3.4 — Framework Comparison (Bonus +5)[m
 [m
 Chỉ làm sau khi hoàn thành 3.1–3.3. Chọn hai framework trong RAGAS, DeepEval[m
 và TruLens; chạy hoặc thiết kế một so sánh có cùng input dataset.[m
 [m
[31m-| Tiêu chí | Framework 1: ____ | Framework 2: ____ |[m
[32m+[m[32m| Tiêu chí | Framework 1: RAGAS | Framework 2: DeepEval |[m
 |---|---|---|[m
[31m-| Setup complexity | | |[m
[31m-| Metrics available | | |[m
[31m-| CI/CD integration | | |[m
[31m-| Kết quả trên cùng dataset | | |[m
[31m-| Insight rút ra | | |[m
[32m+[m[32m| Setup complexity | Medium: map question, answer, reference, retrieved contexts; configure judge/model. | Medium: create test cases and configure metric/judge model. |[m
[32m+[m[32m| Metrics available | Faithfulness, answer relevancy, context recall, context precision. | Faithfulness, answer relevancy and contextual/retrieval metrics. |[m
[32m+[m[32m| CI/CD integration | Call evaluation from Python job/test and gate on thresholds. | Integrates with pytest-style tests and thresholds. |[m
[32m+[m[32m| Kết quả trên cùng dataset | Not run; design would use the same 20 records and traces. | Not run; design would use identical records and judge config. |[m
[32m+[m[32m| Insight rút ra | Normalize rubric and hold judge/model/input constant before comparing scores. | Metric definitions and judge configuration can change scores and failure order. |[m
 [m
 - Scores có nhất quán không?[m
 - Framework nào strict hơn và vì sao?[m
 - Hai framework có tìm ra cùng failure cases không?[m
 [m
[31m-> *Phân tích:*[m
[32m+[m[32m> Đây là comparison design, không phải execution; không có framework scores nào được tạo. Để so sánh, chạy cùng 20 question/expected/actual/retrieved chunks, cố định judge model/version/prompt, lặp ít nhất ba lần, rồi so average, per-case rank correlation, failure overlap và disagreement với human labels. Hiện chưa thể kết luận scores có nhất quán không, framework nào strict hơn, hay chúng tìm cùng failure cases.[m
 [m
 ### Exercise 3.5 — Retrieval Reranking (Bonus +5)[m
 [m
[36m@@ -296,20 +297,20 @@[m [mthay đổi Context Recall hay không.[m
 [m
 | ID | Recall before | Recall after | Precision before | Precision after | Delta Precision |[m
 |---|---:|---:|---:|---:|---:|[m
[31m-| | | | | | |[m
[31m-| | | | | | |[m
[31m-| | | | | | |[m
[31m-| | | | | | |[m
[31m-| | | | | | |[m
[31m-| **Avg** | | | | | |[m
[32m+[m[32m| E01 | 0.938 | 0.938 | 1.000 | 1.000 | +0.000 |[m
[32m+[m[32m| M01 | 0.929 | 0.929 | 0.917 | 0.867 | -0.050 |[m
[32m+[m[32m| M03 | 0.966 | 0.966 | 0.950 | 0.950 | +0.000 |[m
[32m+[m[32m| H01 | 0.889 | 0.889 | 1.000 | 1.000 | +0.000 |[m
[32m+[m[32m| A01 | 0.423 | 0.423 | 1.000 | 1.000 | +0.000 |[m
[32m+[m[32m| **Avg** | **0.829** | **0.829** | **0.973** | **0.963** | **-0.010** |[m
 [m
 **Tại sao Recall dự kiến không đổi?**[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Context Recall dùng union tokens của toàn bộ retrieved chunks nên không phụ thuộc thứ tự. Reranker giữ nguyên cùng năm chunks, do đó tập token và expected-answer coverage không đổi. Runtime check xác nhận cùng multiset chunks và Recall trước/sau bằng nhau.[m
 [m
 **Khi nào reranking không đủ và cần sửa retriever/query/chunking?**[m
 [m
[31m-> *Câu trả lời:*[m
[32m+[m[32m> Nếu evidence cần thiết không nằm trong top-k candidates, reranking không thể tăng coverage. Cần cải thiện query/intent routing, candidate recall, BM25 hoặc chunk boundaries. Lexical reranking cũng không hiểu paraphrase; ở M01 nó làm precision giảm 0.050 dù recall không đổi.[m
 [m
 ---[m
 [m
[36m@@ -323,11 +324,11 @@[m [mHoàn thành `reflection.md` bằng kết quả thật từ Exercise 3.2.[m
 [m
 Hoàn thành kiểm tra cuối trong khoảng 11:50–12:00.[m
 [m
[31m-- [ ] Tất cả required tests pass.[m
[31m-- [ ] `golden_dataset.json` validate thành công.[m
[31m-- [ ] Exercise 3.1 hoàn thành trong file JSON và bảng kết quả phía trên.[m
[31m-- [ ] Exercise 3.2 có năm metrics, aggregate report và ba cases thấp nhất.[m
[31m-- [ ] Exercise 3.3 có rubric 1–5 và bias controls.[m
[31m-- [ ] `reflection.md` có ba failure analyses và regression strategy.[m
[31m-- [ ] Đã copy `template.py` thành `solution/solution.py`.[m
[31m-- [ ] Exercise 3.4 và 3.5 chỉ làm nếu chọn bonus.[m
[32m+[m[32m- [x] Tất cả required tests pass; reranking bonus test cũng pass.[m
[32m+[m[32m- [x] `golden_dataset.json` validate thành công.[m
[32m+[m[32m- [x] Exercise 3.1 hoàn thành trong file JSON và bảng kết quả phía trên.[m
[32m+[m[32m- [x] Exercise 3.2 có năm metrics, aggregate report và ba cases thấp nhất.[m
[32m+[m[32m- [x] Exercise 3.3 có rubric 1–5 và bias controls.[m
[32m+[m[32m- [x] `reflection.md` có ba failure analyses và regression strategy.[m
[32m+[m[32m- [x] `template.py` và `solution/solution.py` được giữ đồng bộ.[m
[32m+[m[32m- [x] Exercise 3.4 có comparison design; Exercise 3.5 được implement/test và đo trên 5 cases.[m
[1mdiff --git a/golden_dataset.json b/golden_dataset.json[m
[1mindex f80cd0c..64c34c8 100644[m
[1m--- a/golden_dataset.json[m
[1m+++ b/golden_dataset.json[m
[36m@@ -5,212 +5,213 @@[m
     {[m
       "id": "E01",[m
       "difficulty": "easy",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "How many USB-C ports does the NovaBook 14 have, and what charger wattage is specified?",[m
[32m+[m[32m      "expected_answer": "The NovaBook 14 has two USB-C ports and charges through either port with a 65 W USB-C Power Delivery adapter.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "01_product_catalog.md", "text": "The NovaBook 14 is a 14-inch laptop with two USB-C ports, one USB-A port, 16 GB of memory, and a 512 GB solid-state drive. It charges through either USB-C port with a 65 W USB-C Power Delivery adapter. A lower-wattage adapter may charge slowly but may not maintain charge during heavy use."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "E02",[m
       "difficulty": "easy",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "When can I cancel an online order, and is cancellation guaranteed after it enters Packing?",[m
[32m+[m[32m      "expected_answer": "You can cancel while the order is Confirmed. Once it is Packing, cancellation is not guaranteed; support may request carrier interception, but success is not guaranteed and its fee is non-refundable.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "02_orders_and_payments.md", "text": "An order can be cancelled from the account page while its status is `Confirmed`. Once the status becomes `Packing`, cancellation is no longer guaranteed. Support may request a carrier interception, but interception fees are non-refundable and success is not guaranteed. If interception fails, the customer must use the return process after delivery."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "E03",[m
       "difficulty": "easy",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "What is the annual OrbitPlus membership price and its main benefits?",[m
[32m+[m[32m      "expected_answer": "OrbitPlus costs USD 49 per year and includes free standard shipping on eligible domestic orders, a 5% discount on regularly priced OrbitTech accessories, and priority chat support.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "03_promotions_and_membership.md", "text": "OrbitPlus is an annual membership costing USD 49. Active members receive free standard shipping on eligible domestic orders, a 5% member discount on regularly priced OrbitTech accessories, and priority chat support. Membership does not discount devices, repair charges, gift cards, taxes, express shipping, or products already marked as clearance."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "E04",[m
       "difficulty": "easy",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "What are the normal domestic standard and express delivery estimates after dispatch?",[m
[32m+[m[32m      "expected_answer": "Standard shipping normally takes three to five business days after dispatch; express normally takes one to two business days. These are estimates, not guarantees, and designated remote areas require two additional business days.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "04_shipping_and_delivery.md", "text": "Standard domestic shipping normally arrives in three to five business days after dispatch. Express shipping normally arrives in one to two business days after dispatch. These are service estimates, not guarantees. Orders to designated remote areas require two additional business days. Weekends and public carrier holidays are not business days."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "E05",[m
       "difficulty": "easy",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "For an order placed on or after September 1, 2026, what is the return window and restocking fee for an opened standard device?",[m
[32m+[m[32m      "expected_answer": "An opened standard device may be returned within 14 calendar days after confirmed delivery and is subject to a 10% restocking fee. A verified defective device returned within the window is not charged that fee.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "05_returns_and_exchanges.md", "text": "For orders placed on or after September 1, 2026, an unopened standard device may be returned within 30 calendar days after confirmed delivery. An opened standard device may be returned within 14 calendar days and is subject to a 10% restocking fee. A defective device verified during the return window is not charged a restocking fee. OrbitPlus may extend only the unopened-device window as described in `03_promotions_and_membership.md`."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "M01",[m
       "difficulty": "medium",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "I paid for part of an order with a gift card and the rest with my card. How are those amounts refunded if I return it?",[m
[32m+[m[32m      "expected_answer": "Refunds go to the original payment methods. The gift-card-funded portion cannot be refunded as cash and returns to a replacement gift card; the card-funded portion returns to the original card.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""},[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "02_orders_and_payments.md", "text": "Customers may pay by supported credit or debit card, OrbitTech gift card, or bank transfer. Up to two gift cards may be combined with one card payment. Promotional codes and membership benefits follow `03_promotions_and_membership.md`. OrbitTech cannot refund cash for a gift-card-funded portion; that amount returns to a replacement gift card."},[m
[32m+[m[32m        {"source_doc": "05_returns_and_exchanges.md", "text": "After inspection, refunds are issued to the original payment methods within five to seven business days. Gift-card portions return to a replacement gift card. Original standard-shipping fees are not refunded for preference returns. A return caused by a verified defect or OrbitTech shipping error includes a prepaid return label. Warranty service after the return window follows `06_warranty_policy.md` and `07_repair_and_technical_support.md`."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "M02",[m
       "difficulty": "medium",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "If I cancel OrbitPlus within 14 days, when do I get a membership refund?",[m
[32m+[m[32m      "expected_answer": "A cancellation within 14 calendar days receives a full membership refund only if no member discount, free shipping, or priority service has been used. If any benefit was used, membership remains active until annual expiry and is not refunded.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""},[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "03_promotions_and_membership.md", "text": "The membership benefit must be active when the order is placed. Activating OrbitPlus after an order does not retroactively change the price or shipping fee. Cancelling membership within 14 calendar days produces a full membership refund only if no member discount, free shipping, or priority service has been used. Otherwise, the membership remains active until its annual expiry and is not refunded."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "M03",[m
       "difficulty": "medium",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "When is a tracked package considered delayed, and can OrbitTech refund or replace it while a carrier trace is active?",[m
[32m+[m[32m      "expected_answer": "It is delayed when tracking has no update for three business days beyond the latest estimated delivery date. Support may open a carrier trace, but no refund or replacement is issued while the trace is within its five-business-day investigation period.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""},[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "04_shipping_and_delivery.md", "text": "Tracking becomes available after dispatch and may take up to 24 hours to show movement. A package is considered delayed when it has no tracking update for three business days beyond the latest estimated delivery date. At that point, support may open a carrier trace. A refund or replacement is not issued while an active trace is within its five-business-day investigation period."}[m
       ],[m
       "attack_type": null[m
     },[m
     {[m
       "id": "M04",[m
       "difficulty": "medium",[m
[31m-      "question": "",[m
[31m-      "expected_answer": "",[m
[32m+[m[32m      "question": "How long is a NovaBook 14 covered by warranty, what proof is needed, and what remedies might follow diagnosis?",[m
[32m+[m[32m      "expected_answer": "The NovaBook 14 has a 24-month limited hardware warranty beginning at confirmed delivery for a shipped order. A claim requires an order number or other acceptable proof of purchase. After diagnosis, OrbitTech may repair, replace it with an equivalent new or refurbished unit, or refund when the first two remedies are not reasonable; OrbitTech chooses the remedy.",[m
       "contexts": [[m
[31m-        {"source_doc": "", "text": ""},[m
[31m-        {"source_doc": "", "text": ""}[m
[32m+[m[32m        {"source_doc": "06_warranty_policy.md", "text": "OrbitTech provides a 24-month limited hardware warranty for the NovaBook 14, PulsePhone X, and HomeHub Mini. The AeroBuds Pro and separately purchased OrbitTech accessories have a 12-month warranty. Coverage 
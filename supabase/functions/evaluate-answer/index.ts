// Supabase Edge Functions run on Deno runtime.
// Ambient declaration so local IDE/VS Code doesn't show red squiggly errors.
declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
  serve(handler: (req: Request) => Promise<Response> | Response): void;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EvaluationRequest {
  userId?: string;
  section: "converser" | "native_mind" | "speaker";
  userAnswer: string;
  context?: {
    level?: number;
    targetWord?: string;
    turnCount?: number;
    cumulativeScore?: number;
    phase?: string;
    topic?: string;
    scenario?: string;
    task?: string;
    history?: Array<{ role: "user" | "assistant"; content: string }>;
  };
}

Deno.serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY environment variable is not set." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const payload: EvaluationRequest = await req.json();
    const { section, userAnswer, context } = payload;

    if (!userAnswer || userAnswer.trim() === "") {
      return new Response(
        JSON.stringify({ error: "userAnswer is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let systemInstruction = "";
    let userPrompt = "";

    if (section === "converser") {
      const level = context?.level ?? 0;
      const currentTurn = context?.turnCount ?? 1;
      const currentCumScore = context?.cumulativeScore ?? 0;
      const topic = context?.topic || context?.phase || "general conversation";
      const historyStr = context?.history && context.history.length > 0
        ? context.history.map((h) => `${h.role === "user" ? "Learner" : "Partner"}: ${h.content}`).join("\n")
        : "(Beginning of conversation)";

      // Universal Level Formula — Applies to ANY phase/topic
      const levelQuestionGuides: Record<number, string> = {
        0: `Level 0 (Simple Choices & Favorites) — Act as a friendly peer chatting casually. Ask simple A or B choice questions or ask about simple favorites related to "${topic}" (e.g. "Do you like cats or dogs?", "What is your favorite food?"). Keep questions very short (under 10 words). Single words or short phrases from the learner are completely valid.`,
        1: `Level 1 (Daily Life & Real Activities) — Ask about the learner's actual routine, current day, or real actions related to "${topic}" (e.g. "What did you eat for breakfast today?", "What are you planning to do this afternoon?"). Expect short phrases or simple sentences.`,
        2: `Level 2 (Opinions & Reasons / 'Why') — Ask the learner to express a preference or experience and explain WHY (e.g. "If you could visit any city, where would you go and why?", "What makes that your favorite thing?"). Expect a full sentence with an explanation.`,
        3: `Level 3 (Problem Solving & Collaborative Dilemma) — Present a real situational challenge or decision related to "${topic}" where you need their advice or ideas (e.g. "We are planning an event/trip and have a dilemma: ... what do you suggest we do?", "A plan went wrong: ... how should we solve it?"). Expect proactive ideas, suggestions, and detailed reasoning from the learner.`,
      };
      const levelQuestionGuide = levelQuestionGuides[level] ?? `Ask natural questions appropriate for Level ${level} about "${topic}".`;

      systemInstruction = `
You are a friendly, natural English conversation partner chatting with a learner about "${topic}".
You are talking to a learner at Level ${level} (0 = simplest, 3 = most advanced).

CRITICAL CONVERSATION RULES:
1. NEVER ask theoretical or meta-linguistic questions like "How do you greet someone in English?", "What do you say in the morning?", or "How do you say hello to an elder?". That is an interrogation, NOT a real conversation!
2. Chat like a real human friend talking about real life, preferences, stories, and activities.
3. Advance the conversation forward with every turn. Acknowledge their previous answer warmly in 1 short sentence, then ask the next question following the level objective.
4. Level ${level} Objective:
${levelQuestionGuide}
5. Reply in natural, conversational English suited to Level ${level}.
6. Ask ONE clear question at a time.
7. Stay 100% in English. Never translate or speak in Indonesian.

SCORING RULES:
1. This conversation must last AT LEAST 7 exchanges (turns) before it can be considered complete — never end or award full marks after just one good answer.
2. Each turn is worth a MAXIMUM of 14.29 points toward a cumulative total of 100. Points awarded = 14.29 × (relevance fraction 0.0–1.0). A perfect answer still only earns ~14.29 pts that turn — never more.
3. Keep a running cumulative score across all turns.
4. The conversation is complete (isComplete: true) ONLY when: (a) at least 7 turns have happened, AND (b) cumulative score >= 100. If below 100 after 7 turns, continue until it reaches 100.

EVALUATION STANDARDS:
- Level 0: Accept single words or short phrases as fully relevant.
- Level 1: Expect short phrases or simple sentences.
- Level 2: Expect a full sentence that directly and appropriately responds with a reason.
- Level 3: Expect a complete response that shows initiative (asks back, adds creative detail).

OUTPUT FORMAT (JSON only, no extra text):
{
  "aiReply": "<your natural conversational reply in English, acknowledging their answer and asking your next varied question>",
  "turnScore": <number 0-14.29, points earned this turn>,
  "cumulativeScore": <number 0-100, running total including this turn (cap at 100)>,
  "turnCount": <integer, total turns so far including this one>,
  "isComplete": <true only if turnCount >= 7 AND cumulativeScore >= 100, otherwise false>,
  "score": <same as cumulativeScore>,
  "feedback": "<short encouraging note on their answer>",
  "betterAlternative": "<a natural native alternative if helpful, or empty string>"
}
`;

      userPrompt = `
Topic: ${topic}
Current Level: ${level}
Current Turn Count so far: ${currentTurn}
Current Cumulative Score so far: ${currentCumScore}

Conversation History:
${historyStr}

Learner's Latest Answer:
"${userAnswer}"
`;
    } else if (section === "speaker") {
      // Speaker / Pronunciation Evaluation
      const targetWord = context?.targetWord || "";
      const level = context?.level ?? 0;

      systemInstruction = `
You are an encouraging pronunciation coach helping an English learner practice speaking.
The target word the learner was asked to say is: "${targetWord}".
The speech recognition engine captured this from the learner: "${userAnswer}".

YOUR EVALUATION TASK:
1. Determine if the learner's spoken input matches, is phonetically equivalent, or is close enough to "${targetWord}".
2. Be forgiving of standard speech-to-text noise or minor casing/punctuation differences.
3. Scoring criteria:
   - Matches "${targetWord}" or very close: score 85 to 100.
   - Minor phonetic difference or partial match: score 70 to 84.
   - Wrong word or completely unintelligible: score 0 to 65.
   - Passing threshold is 75.

4. Tone & Content Guidelines:
   - "aiReply": Short enthusiastic cheer (e.g. "Awesome pronunciation! 🎉", "Great job! ✨", "Nice attempt! 💪", "Try once more! 🎯").
   - "feedback": 1-2 friendly, simple sentences explaining how to pronounce "${targetWord}" cleanly. Mention mouth or vowel tips in beginner-friendly English.
   - "betterAlternative": Clear phonetic breakdown (e.g., "/${targetWord}/" or phonetic syllables).
   - "score": An integer from 0 to 100.

You MUST respond strictly in valid JSON format:
{
  "score": 90,
  "aiReply": "Awesome pronunciation! 🎉",
  "feedback": "You pronounced '${targetWord}' clearly! Keep up the good work.",
  "betterAlternative": "/${targetWord}/"
}
`;

      userPrompt = `
Target Word to Pronounce: "${targetWord}"
Learner's Spoken Input: "${userAnswer}"
Level: ${level}
`;
    } else {
      // Native Mind / Strategy Evaluation
      const scenario = context?.scenario || context?.task || "Spontaneous everyday English reaction.";

      systemInstruction = `
You are a warm, encouraging English teacher evaluating the learner's situational IDEAS and STRATEGY in the Native Mind phase.
IMPORTANT: At this stage, do NOT focus on textbook grammar or formal speech. Focus primarily on their CORE IDEA, LOGIC, and PROBLEM-SOLVING SOLUTION (e.g., how they actually help or solve the challenge in the scenario).

LANGUAGE LEVEL (CRUCIAL):
- Use simple, beginner-friendly English (A2-B1 level).
- Use familiar, everyday words that learners easily understand.
- Avoid advanced vocabulary, complex idioms, or academic explanations.
- Keep sentences short, positive, and clear.

Evaluation Criteria:
1. Practicality & Logic of the Idea: Did they propose a sensible, simple, or effective solution to the situation?
2. Spontaneous Thought: Can you clearly see their thinking and problem-solving reflex?

Tone Guidelines:
- "aiReply": A warm, simple encouragement title (e.g., "Nice try! 👏", "Great idea! 💡", "Good thinking! ✨", "Well done! 👍").
- "feedback": 2-3 short, friendly sentences in simple English. Speak like a kind teacher. First, praise their idea (e.g., "I love your idea to use the rope!"). Then, give a simple tip to say it naturally.
- "betterAlternative": A short, clear, and natural sentence using familiar everyday words that a native speaker would easily say.
- "score": A score (0-100) reflecting their practical idea + spontaneous communication.

You MUST respond strictly in valid JSON format with this exact structure:
{
  "score": 85,
  "aiReply": "Nice try! 👏",
  "feedback": "I love your idea of using the rope to help him! To say it simply and naturally, you can say it like this.",
  "betterAlternative": "I'd use that rope to help pull the child across."
}
`;

      userPrompt = `
Scenario / Challenge:
"${scenario}"

User's Spontaneous Response:
"${userAnswer}"
`;
    }

    let responseSchema: any = undefined;

    if (section === "converser") {
      responseSchema = {
        type: "OBJECT",
        properties: {
          aiReply: { type: "STRING" },
          turnScore: { type: "NUMBER" },
          cumulativeScore: { type: "NUMBER" },
          turnCount: { type: "INTEGER" },
          isComplete: { type: "BOOLEAN" },
          score: { type: "NUMBER" },
          feedback: { type: "STRING" },
          betterAlternative: { type: "STRING" }
        },
        required: ["aiReply", "turnScore", "cumulativeScore", "turnCount", "isComplete", "score", "feedback", "betterAlternative"]
      };
    } else {
      responseSchema = {
        type: "OBJECT",
        properties: {
          score: { type: "INTEGER" },
          aiReply: { type: "STRING" },
          feedback: { type: "STRING" },
          betterAlternative: { type: "STRING" }
        },
        required: ["score", "aiReply", "feedback", "betterAlternative"]
      };
    }

    const candidateModels = [
      "gemini-3.1-flash-lite",
      "gemini-flash-latest",
      "gemini-3.5-flash",
      "gemini-3.6-flash",
    ];

    const geminiBody: any = {
      systemInstruction: {
        parts: [{ text: systemInstruction }]
      },
      contents: [
        {
          role: "user",
          parts: [{ text: userPrompt }]
        }
      ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: responseSchema,
        temperature: 0.6,
      }
    };

    let geminiRes: Response | null = null;
    let lastErrText = "";
    let usedModel = "";

    for (const model of candidateModels) {
      try {
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
        const res = await fetch(geminiUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(geminiBody),
          signal: AbortSignal.timeout(6000),
        });

        if (res.ok) {
          geminiRes = res;
          usedModel = model;
          break;
        } else {
          lastErrText = await res.text();
          console.warn(`Model ${model} failed with status ${res.status}: ${lastErrText}`);
        }
      } catch (fetchErr: any) {
        lastErrText = fetchErr.message;
        console.warn(`Model ${model} threw error: ${fetchErr.message}`);
      }
    }

    if (!geminiRes) {
      return new Response(
        JSON.stringify({ error: `All Gemini models failed. Last error: ${lastErrText}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData = await geminiRes.json();
    const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      return new Response(
        JSON.stringify({ error: "Empty response from Gemini." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse returned JSON from Gemini with sanitization fallback
    let evaluationResult: any;
    try {
      evaluationResult = JSON.parse(rawText);
    } catch {
      let cleaned = rawText.replace(/```json\s*/gi, "").replace(/```\s*/g, "").trim();
      const firstIdx = cleaned.indexOf("{");
      const lastIdx = cleaned.lastIndexOf("}");
      if (firstIdx !== -1 && lastIdx !== -1 && lastIdx > firstIdx) {
        cleaned = cleaned.substring(firstIdx, lastIdx + 1);
      }
      try {
        evaluationResult = JSON.parse(cleaned);
      } catch (parseErr: any) {
        console.error("Failed to parse Gemini output:", rawText);
        return new Response(
          JSON.stringify({ error: `JSON Parse error: ${parseErr.message}`, raw: rawText }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        section,
        model: usedModel,
        evaluation: evaluationResult
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

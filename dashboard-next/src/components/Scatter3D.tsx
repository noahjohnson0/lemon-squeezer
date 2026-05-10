"use client";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Text, Line } from "@react-three/drei";
import { useMemo, useRef } from "react";
import * as THREE from "three";
import { Run, colorForModel, unique } from "@/lib/data";

type ScatterPoint = {
  run: Run;
  x: number; // wall_seconds (log)
  y: number; // score_pct
  z: number; // tokens (log)
  color: string;
};

function Points({ points, onSelect }: { points: ScatterPoint[]; onSelect: (id: string) => void }) {
  return (
    <>
      {points.map((p) => (
        <Pulse key={p.run.run_id} point={p} onSelect={onSelect} />
      ))}
    </>
  );
}

function Pulse({ point, onSelect }: { point: ScatterPoint; onSelect: (id: string) => void }) {
  const ref = useRef<THREE.Mesh>(null);
  // Subtle floating animation per-point with deterministic seed from run_id
  const seed = useMemo(
    () => point.run.run_id.split("").reduce((s, c) => s + c.charCodeAt(0), 0) % 1000,
    [point.run.run_id]
  );
  useFrame((state) => {
    if (!ref.current) return;
    const t = state.clock.elapsedTime;
    ref.current.position.y = point.y + Math.sin(t * 0.6 + seed) * 0.03;
  });
  return (
    <mesh
      ref={ref}
      position={[point.x, point.y, point.z]}
      onClick={(e) => {
        e.stopPropagation();
        onSelect(point.run.run_id);
      }}
      onPointerOver={(e) => {
        e.stopPropagation();
        document.body.style.cursor = "pointer";
      }}
      onPointerOut={() => {
        document.body.style.cursor = "auto";
      }}
    >
      <sphereGeometry args={[0.08, 16, 16]} />
      <meshStandardMaterial
        color={point.color}
        emissive={point.color}
        emissiveIntensity={0.5}
        roughness={0.3}
      />
    </mesh>
  );
}

function Axes() {
  // Simple line segments + labels for axes.
  const lineColor = "#3a4453";
  const tickStyle = { fontSize: 0.18, color: "#8b949e" };
  return (
    <group>
      {/* X axis (wall log10) */}
      <Line points={[[0, 0, 0], [10, 0, 0]]} color={lineColor} lineWidth={1} />
      {/* Y axis (score) */}
      <Line points={[[0, 0, 0], [0, 5, 0]]} color={lineColor} lineWidth={1} />
      {/* Z axis (tokens log10) */}
      <Line points={[[0, 0, 0], [0, 0, 10]]} color={lineColor} lineWidth={1} />
      <Text {...tickStyle} position={[10.4, 0, 0]} anchorX="left">wall →</Text>
      <Text {...tickStyle} position={[0, 5.3, 0]} anchorX="left">score →</Text>
      <Text {...tickStyle} position={[0, 0, 10.4]} anchorX="left">tokens →</Text>
      {/* Y grid (0/25/50/75/100) */}
      {[0, 1, 2, 3, 4, 5].map((y) => (
        <Line key={y} points={[[0, y, 0], [10, y, 0]]} color="#1f2733" lineWidth={1} />
      ))}
      {[0, 25, 50, 75, 100].map((s, i) => (
        <Text key={s} {...tickStyle} position={[-0.4, i * 1.25, 0]} anchorX="right">
          {s}%
        </Text>
      ))}
    </group>
  );
}

export default function Scatter3D({ runs, onSelect }: { runs: Run[]; onSelect: (id: string) => void }) {
  const models = unique(runs.map((r) => r.model));
  // Map data to scene coordinates: x in [0..10], y in [0..5] (i.e. score/20), z in [0..10]
  const points: ScatterPoint[] = useMemo(() => {
    if (runs.length === 0) return [];
    const wallVals = runs.map((r) => Math.max(1, r.wall_seconds || 1));
    const tokVals = runs.map((r) => Math.max(1, (r.tokens_in || 0) + (r.tokens_out || 0)));
    const lwMin = Math.log10(Math.min(...wallVals));
    const lwMax = Math.log10(Math.max(...wallVals));
    const ltMin = Math.log10(Math.min(...tokVals));
    const ltMax = Math.log10(Math.max(...tokVals));
    return runs
      .filter((r) => Number.isFinite(r.score_pct))
      .map((r) => {
        const lw = Math.log10(Math.max(1, r.wall_seconds || 1));
        const lt = Math.log10(Math.max(1, (r.tokens_in || 0) + (r.tokens_out || 0)));
        return {
          run: r,
          x: ((lw - lwMin) / Math.max(1e-9, lwMax - lwMin)) * 10,
          y: (r.score_pct / 100) * 5,
          z: ((lt - ltMin) / Math.max(1e-9, ltMax - ltMin)) * 10,
          color: colorForModel(r.model, models),
        };
      });
  }, [runs, models]);

  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <div className="flex items-baseline gap-3 mb-2">
        <h2 className="text-xl font-semibold">Speed × quality × tokens (3D)</h2>
        <span className="chip">drag to spin</span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
        Each glowing dot is one run. <span className="text-[var(--accent)]">X</span> = wall-clock time,{" "}
        <span className="text-[var(--accent)]">Y</span> = rubric score,{" "}
        <span className="text-[var(--accent)]">Z</span> = total tokens. The fast-cheap-good
        cluster sits in the front-bottom-right. Drag to rotate, scroll to zoom, click a point
        for its score breakdown.
      </p>
      <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl overflow-hidden h-[480px]">
        <Canvas camera={{ position: [14, 8, 14], fov: 45 }}>
          <ambientLight intensity={0.5} />
          <pointLight position={[10, 15, 10]} intensity={1} />
          <pointLight position={[-10, 10, -10]} intensity={0.4} color="#d2a8ff" />
          <fog attach="fog" args={["#0a0d12", 18, 40]} />
          <Axes />
          <Points points={points} onSelect={onSelect} />
          <OrbitControls enableDamping target={[5, 2.5, 5]} />
        </Canvas>
      </div>
      <div className="mt-3 flex flex-wrap gap-2 text-xs">
        {models.map((m) => (
          <div
            key={m}
            className="flex items-center gap-1.5 bg-[var(--panel-2)] border border-[var(--border)] px-2 py-1 rounded"
          >
            <span
              className="w-2 h-2 rounded-full"
              style={{ background: colorForModel(m, models), boxShadow: `0 0 6px ${colorForModel(m, models)}` }}
            />
            <span className="font-mono">{m}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

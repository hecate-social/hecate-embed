//! hecate_embed_nif
//!
//! Rustler NIF backing `hecate_embed`. Scaffold implementation: takes a
//! text, computes a deterministic 32-byte hash, expands it into `dim`
//! floats by treating the hash as a seed for a tiny PRNG. Same input
//! always produces the same vector. Useless for retrieval quality,
//! useful for end-to-end wiring tests.
//!
//! Production build should depend on `fastembed-rs` and replace
//! `embed_one` with a real ONNX inference call.

use rustler::{Atom, Binary, Encoder, Env, NifResult, ResourceArc, Term};
use std::sync::Mutex;

mod atoms {
    rustler::atoms! { ok, error, model_not_found }
}

struct ModelResource {
    inner: Mutex<ModelInner>,
}

struct ModelInner {
    model_id: String,
    dim:      usize,
}

#[rustler::nif]
fn load<'a>(env: Env<'a>, model_id: String, dim: usize, _model_dir: String) -> NifResult<Term<'a>> {
    let r = ResourceArc::new(ModelResource {
        inner: Mutex::new(ModelInner { model_id, dim }),
    });
    Ok((atoms::ok(), r).encode(env))
}

#[rustler::nif]
fn embed<'a>(env: Env<'a>, handle: ResourceArc<ModelResource>, text: Binary<'a>) -> NifResult<Term<'a>> {
    let guard = handle.inner.lock().unwrap();
    let vec = embed_one(text.as_slice(), guard.dim);
    Ok((atoms::ok(), vec).encode(env))
}

#[rustler::nif]
fn embed_many<'a>(env: Env<'a>, handle: ResourceArc<ModelResource>, texts: Vec<Binary<'a>>) -> NifResult<Term<'a>> {
    let guard = handle.inner.lock().unwrap();
    let vecs: Vec<Vec<f32>> = texts.iter().map(|t| embed_one(t.as_slice(), guard.dim)).collect();
    Ok((atoms::ok(), vecs).encode(env))
}

/// Deterministic stub embedder: FNV-1a over the bytes, then a splitmix64
/// PRNG expansion to `dim` floats in [-1, 1]. Mean-centred so cosine
/// similarity is non-degenerate for short inputs.
fn embed_one(text: &[u8], dim: usize) -> Vec<f32> {
    // FNV-1a 64-bit
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in text {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }

    let mut out = Vec::with_capacity(dim);
    let mut state = h;
    for _ in 0..dim {
        // splitmix64 step
        state = state.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^= z >> 31;
        // map u64 → f32 in [-1, 1]
        let f = ((z as f64) / (u64::MAX as f64)) * 2.0 - 1.0;
        out.push(f as f32);
    }
    // L2-normalise so cosine similarity behaves
    let norm: f32 = out.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 0.0 {
        for x in &mut out { *x /= norm; }
    }
    out
}

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(ModelResource, env);
    true
}

rustler::init!(
    "hecate_embed_nif",
    [load, embed, embed_many],
    load = on_load
);

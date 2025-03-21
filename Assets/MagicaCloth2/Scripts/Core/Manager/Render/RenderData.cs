﻿// Magica Cloth 2.
// Copyright (c) 2023 MagicaSoft.
// https://magicasoft.jp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;

namespace MagicaCloth2
{
    /// <summary>
    /// 描画対象の管理情報
    /// レンダラーまたはボーンの描画反映を行う
    /// </summary>
    public class RenderData : IDisposable, ITransform
    {
        /// <summary>
        /// 参照カウント。０になると破棄される
        /// </summary>
        public int ReferenceCount { get; private set; }

        /// <summary>
        /// 利用中のプロセス（＝利用カウント）
        /// </summary>
        HashSet<ClothProcess> useProcessSet = new HashSet<ClothProcess>();

        /// <summary>
        /// Meshへの書き込み停止フラグ
        /// </summary>
        bool isSkipWriting;

        //=========================================================================================
        // セットアップデータ
        internal RenderSetupData setupData;
        internal RenderSetupData.UniqueSerializationData preBuildUniqueSerializeData;

        internal string Name => setupData?.name ?? "(empty)";

        internal bool HasSkinnedMesh => setupData?.hasSkinnedMesh ?? false;
        internal bool HasBoneWeight => setupData?.hasBoneWeight ?? false;

        //=========================================================================================
        // オリジナル情報
        Mesh originalMesh;
        SkinnedMeshRenderer skinnedMeshRendere;
        MeshFilter meshFilter;
        List<Transform> transformList;

        // カスタムメッシュ情報
        Mesh customMesh;
        NativeArray<Vector3> localPositions;
        NativeArray<Vector3> localNormals;
        NativeArray<Vector4> localTangents; // option
        NativeArray<BoneWeight> boneWeights;
        BoneWeight centerBoneWeight;

        /// <summary>
        /// カスタムメッシュの状態フラグ(32bit)
        /// </summary>
        private const int Flag_UseCustomMesh = 0; // カスタムメッシュの利用
        private const int Flag_ChangePositionNormal = 1; // 座標および法線の書き込み
        private const int Flag_ChangeBoneWeight = 2; // ボーンウエイトの書き込み
        private const int Flag_ModifyBoneWeight = 3; // ボーンウエイトの変更
        private const int Flag_HasMeshTangent = 4; // オリジナルメッシュが接線を持っているかどうか
        private const int Flag_HasTangent = 5; // 最終的に接線情報を持っているかどうか
        private const int Flag_ChangeTangent = 6; // 接線の書き込み

        private BitField32 flag;

        public bool UseCustomMesh => flag.IsSet(Flag_UseCustomMesh);
        public bool HasMeshTangent => flag.IsSet(Flag_HasMeshTangent);
        public bool HasTangent => flag.IsSet(Flag_HasTangent);

        //=========================================================================================
        public void Dispose()
        {
            // オリジナルメッシュに戻す
            SwapOriginalMesh();

            setupData?.Dispose();
            preBuildUniqueSerializeData = null;

            if (localPositions.IsCreated)
                localPositions.Dispose();
            if (localNormals.IsCreated)
                localNormals.Dispose();
            if (localTangents.IsCreated)
                localTangents.Dispose();
            if (boneWeights.IsCreated)
                boneWeights.Dispose();

            if (customMesh)
                GameObject.Destroy(customMesh);
        }

        public void GetUsedTransform(HashSet<Transform> transformSet)
        {
            setupData?.GetUsedTransform(transformSet);
        }

        public void ReplaceTransform(Dictionary<int, Transform> replaceDict)
        {
            setupData?.ReplaceTransform(replaceDict);
        }

        /// <summary>
        /// 初期化（メインスレッドのみ）
        /// この処理はスレッド化できないので少し負荷がかかるが即時実行する
        /// </summary>
        /// <param name="ren"></param>
        internal void Initialize(
            Renderer ren,
            RenderSetupData referenceSetupData,
            RenderSetupData.UniqueSerializationData referencePreBuildUniqueSetupData,
            RenderSetupSerializeData referenceInitSetupData
            )
        {
            Debug.Assert(ren);

            // セットアップデータ作成
            // PreBuildでは外部から受け渡される
            if (referenceSetupData != null && referencePreBuildUniqueSetupData != null)
            {
                setupData = referenceSetupData;
                preBuildUniqueSerializeData = referencePreBuildUniqueSetupData;

                originalMesh = preBuildUniqueSerializeData.originalMesh;
                skinnedMeshRendere = preBuildUniqueSerializeData.skinRenderer;
                meshFilter = preBuildUniqueSerializeData.meshFilter;
                transformList = preBuildUniqueSerializeData.transformList;
            }
            else
            {
                setupData = new RenderSetupData(referenceInitSetupData, ren);
                preBuildUniqueSerializeData = null;

                originalMesh = setupData.originalMesh;
                skinnedMeshRendere = setupData.skinRenderer;
                meshFilter = setupData.meshFilter;
                transformList = setupData.transformList;
            }

            // オリジナルメッシュの接線情報を確認
            flag.SetBits(Flag_HasMeshTangent, originalMesh.HasVertexAttribute(UnityEngine.Rendering.VertexAttribute.Tangent));
            //Debug.Log($"OriginalMesh[{originalMesh.name}] hasTangent:{originalMesh.HasVertexAttribute(UnityEngine.Rendering.VertexAttribute.Tangent)}");

            // センタートランスフォーム用ボーンウエイト
            centerBoneWeight = new BoneWeight();
            centerBoneWeight.boneIndex0 = setupData.renderTransformIndex;
            centerBoneWeight.weight0 = 1.0f;
        }

        internal ResultCode Result => setupData?.result ?? ResultCode.None;

        //=========================================================================================
        internal int AddReferenceCount()
        {
            ReferenceCount++;
            return ReferenceCount;
        }

        internal int RemoveReferenceCount()
        {
            ReferenceCount--;
            return ReferenceCount;
        }

        //=========================================================================================
        void SwapCustomMesh()
        {
            Debug.Assert(setupData != null);

            if (setupData.IsFaild())
                return;
            if (originalMesh == null)
                return;
            if (UseCustomMesh)
                return;

            // カスタムメッシュの作成
            if (customMesh == null)
            {
                //Debug.Assert(setupData.originalMesh);
                // クローン作成
                customMesh = GameObject.Instantiate(originalMesh);
                customMesh.MarkDynamic();

                // 作業配列
                int vertexCount = setupData.vertexCount;
                localPositions = new NativeArray<Vector3>(vertexCount, Allocator.Persistent);
                localNormals = new NativeArray<Vector3>(vertexCount, Allocator.Persistent);
                if (HasMeshTangent)
                    localTangents = new NativeArray<Vector4>(vertexCount, Allocator.Persistent);
                if (HasBoneWeight)
                    boneWeights = new NativeArray<BoneWeight>(vertexCount, Allocator.Persistent);

                // bind pose
                if (HasBoneWeight)
                {
                    int transformCount = preBuildUniqueSerializeData != null ? preBuildUniqueSerializeData.transformList.Count : setupData.TransformCount;
                    var bindPoseList = new List<Matrix4x4>(transformCount);
                    bindPoseList.AddRange(setupData.bindPoseList);
                    // rootBone/skinning bones
                    while (bindPoseList.Count < transformCount)
                        bindPoseList.Add(Matrix4x4.identity);
                    customMesh.bindposes = bindPoseList.ToArray();

                    // スキニング用ボーンを書き換える
                    // このリストにはオリジナルのスキニングボーン＋レンダラーのトランスフォームが含まれている
                    skinnedMeshRendere.bones = transformList.ToArray();
                }
            }

            // 作業バッファリセット
            ResetCustomMeshWorkData();

            // カスタムメッシュに表示切り替え
            SetMesh(customMesh);
            flag.SetBits(Flag_UseCustomMesh, true);
        }

        void ResetCustomMeshWorkData()
        {
            // オリジナルデータをコピーする
            if (setupData.HasMeshDataArray)
            {
                var meshData = setupData.meshDataArray[0];
                meshData.GetVertices(localPositions);
                meshData.GetNormals(localNormals);
                if (HasMeshTangent)
                {
                    meshData.GetTangents(localTangents);
                    flag.SetBits(Flag_HasTangent, true); // 最終的な接線あり
                }
            }
            else
            {
                NativeArray<Vector3>.Copy(setupData.localPositions, localPositions);
                NativeArray<Vector3>.Copy(setupData.localNormals, localNormals);
                if (HasMeshTangent && setupData.HasTangent)
                {
                    NativeArray<Vector4>.Copy(setupData.localTangents, localTangents);
                    flag.SetBits(Flag_HasTangent, true); // 最終的な接線あり
                }
            }
            if (HasBoneWeight)
            {
                setupData.GetBoneWeightsRun(boneWeights);
            }
        }

        /// <summary>
        /// オリジナルメッシュに戻す
        /// </summary>
        void SwapOriginalMesh()
        {
            if (UseCustomMesh && setupData != null)
            {
                SetMesh(originalMesh);

                if (skinnedMeshRendere != null)
                {
                    skinnedMeshRendere.bones = transformList.ToArray();
                }
            }
            flag.SetBits(Flag_UseCustomMesh, false);
        }

        /// <summary>
        /// レンダラーにメッシュを設定する
        /// </summary>
        /// <param name="mesh"></param>
        void SetMesh(Mesh mesh)
        {
            if (mesh == null)
                return;

            if (setupData != null)
            {
                if (meshFilter != null)
                {
                    meshFilter.mesh = mesh;
                }
                else if (skinnedMeshRendere != null)
                {
                    skinnedMeshRendere.sharedMesh = mesh;
                }
            }
        }

        //=========================================================================================
        /// <summary>
        /// 利用の開始
        /// 利用するということはメッシュに頂点を書き込むことを意味する
        /// 通常コンポーネントがEnableになったときに行う
        /// </summary>
        public void StartUse(ClothProcess cprocess)
        {
            UpdateUse(cprocess, 1);
        }

        /// <summary>
        /// 利用の停止
        /// 停止するということはメッシュに頂点を書き込まないことを意味する
        /// 通常コンポーネントがDisableになったときに行う
        /// </summary>
        public void EndUse(ClothProcess cprocess)
        {
            //Debug.Assert(useProcessSet.Count > 0);
            UpdateUse(cprocess, -1);
        }

        internal void UpdateUse(ClothProcess cprocess, int add)
        {
            if (add > 0)
            {
                useProcessSet.Add(cprocess);
            }
            else if (add < 0)
            {
                //Debug.Assert(useProcessSet.Count > 0);
                if (useProcessSet.Contains(cprocess))
                    useProcessSet.Remove(cprocess);
                else
                    return;
            }

            // Invisible状態
            bool invisible = useProcessSet.Any(x => (x.IsCameraCullingInvisible() && x.IsCameraCullingKeep() == false) || x.IsDistanceCullingInvisible());

            // 状態変更
            if (invisible || useProcessSet.Count == 0)
            {
                // 利用停止
                // オリジナルメッシュに切り替え
                SwapOriginalMesh();
            }
            else if (add == 0 && useProcessSet.Count > 0)
            {
                // カリング復帰
                // カスタムメッシュに切り替え、および作業バッファ作成
                // すでにカスタムメッシュが存在する場合は作業バッファのみ再初期化する
                SwapCustomMesh();
                flag.SetBits(Flag_ModifyBoneWeight, true);
            }
            else if (add > 0 && useProcessSet.Count == 1)
            {
                // 利用開始
                // カスタムメッシュに切り替え、および作業バッファ作成
                // すでにカスタムメッシュが存在する場合は作業バッファのみ再初期化する
                SwapCustomMesh();
                flag.SetBits(Flag_ModifyBoneWeight, true);
            }
            else if (add != 0)
            {
                // 複数から利用されている状態で１つが停止した。
                // バッファを最初期化する
                ResetCustomMeshWorkData();
                flag.SetBits(Flag_ModifyBoneWeight, true);
            }

            //Debug.Log($"add:{add}, invisible:{invisible}, useCount:{useProcessSet.Count}, ModifyBoneWeight = {flag.IsSet(Flag_ModifyBoneWeight)}");
        }

        //=========================================================================================
        /// <summary>
        /// Meshへの書き込みフラグを更新する
        /// </summary>
        internal void UpdateSkipWriting()
        {
            isSkipWriting = false;
            foreach (var cprocess in useProcessSet)
            {
                if (cprocess.IsSkipWriting())
                    isSkipWriting = true;
            }
        }

        //=========================================================================================
        internal void WriteMesh()
        {
            if (UseCustomMesh == false || useProcessSet.Count == 0)
                return;

            // 書き込み停止中ならスキップ
            if (isSkipWriting)
                return;

            //Debug.Log($"WriteMesh [{Name}] ChangePositionNormal:{flag.IsSet(Flag_ChangePositionNormal)}, ChangeBoneWeight:{flag.IsSet(Flag_ChangeBoneWeight)}");

            // メッシュに反映
            if (flag.IsSet(Flag_ChangePositionNormal))
            {
                customMesh.SetVertices(localPositions);
                customMesh.SetNormals(localNormals);
                if (HasTangent && flag.IsSet(Flag_ChangeTangent))
                    customMesh.SetTangents(localTangents);
            }
            if (flag.IsSet(Flag_ChangeBoneWeight) && HasBoneWeight)
            {
                customMesh.boneWeights = boneWeights.ToArray();
                //Debug.Log($"★[{Name}] boneWeights.ToArray(), size:{boneWeights.Length}, F:{Time.frameCount}");
                flag.SetBits(Flag_ModifyBoneWeight, false);
            }

            // 完了
            flag.SetBits(Flag_ChangePositionNormal, false);
            flag.SetBits(Flag_ChangeBoneWeight, false);
            flag.SetBits(Flag_ChangeTangent, false);
        }

        //=========================================================================================
        /// <summary>
        /// メッシュの位置法線を更新
        /// </summary>
        /// <param name="mappingChunk"></param>
        /// <param name="jobHandle"></param>
        /// <returns></returns>
        internal JobHandle UpdatePositionNormal(bool updateTangent, DataChunk mappingChunk, JobHandle jobHandle)
        {
            if (UseCustomMesh == false)
                return jobHandle;

            var vm = MagicaManager.VMesh;

            // 座標・法線・接線の差分書き換え
            if (HasTangent && updateTangent)
            {
                // 接線あり
                var job = new UpdatePositionNormalTangentJob()
                {
                    startIndex = mappingChunk.startIndex,

                    meshLocalPositions = localPositions.Reinterpret<float3>(),
                    meshLocalNormals = localNormals.Reinterpret<float3>(),
                    meshLocalTangents = localTangents.Reinterpret<float4>(),

                    mappingReferenceIndices = vm.mappingReferenceIndices.GetNativeArray(),
                    mappingAttributes = vm.mappingAttributes.GetNativeArray(),
                    mappingPositions = vm.mappingPositions.GetNativeArray(),
                    mappingNormals = vm.mappingNormals.GetNativeArray(),
                    mappingTangents = vm.mappingTangents.GetNativeArray(),
                };
                jobHandle = job.Schedule(mappingChunk.dataLength, 32, jobHandle);

                flag.SetBits(Flag_ChangeTangent, true);
            }
            else
            {
                // 接線なし
                var job = new UpdatePositionNormalJob()
                {
                    startIndex = mappingChunk.startIndex,

                    meshLocalPositions = localPositions.Reinterpret<float3>(),
                    meshLocalNormals = localNormals.Reinterpret<float3>(),

                    mappingReferenceIndices = vm.mappingReferenceIndices.GetNativeArray(),
                    mappingAttributes = vm.mappingAttributes.GetNativeArray(),
                    mappingPositions = vm.mappingPositions.GetNativeArray(),
                    mappingNormals = vm.mappingNormals.GetNativeArray(),
                };
                jobHandle = job.Schedule(mappingChunk.dataLength, 32, jobHandle);
            }

            flag.SetBits(Flag_ChangePositionNormal, true);

            return jobHandle;
        }

        [BurstCompile]
        struct UpdatePositionNormalJob : IJobParallelFor
        {
            public int startIndex;

            [NativeDisableParallelForRestriction]
            [Unity.Collections.WriteOnly]
            public NativeArray<float3> meshLocalPositions;
            [NativeDisableParallelForRestriction]
            [Unity.Collections.WriteOnly]
            public NativeArray<float3> meshLocalNormals;

            // mapping mesh
            [Unity.Collections.ReadOnly]
            public NativeArray<int> mappingReferenceIndices;
            [Unity.Collections.ReadOnly]
            public NativeArray<VertexAttribute> mappingAttributes;
            [Unity.Collections.ReadOnly]
            public NativeArray<float3> mappingPositions;
            [Unity.Collections.ReadOnly]
            public NativeArray<float3> mappingNormals;

            public void Execute(int index)
            {
                int vindex = index + startIndex;

                // 無効頂点なら書き込まない
                var attr = mappingAttributes[vindex];
                if (attr.IsInvalid())
                    return;

                // 固定も書き込まない
                if (attr.IsFixed())
                    return;

                // 書き込む頂点インデックス
                int windex = mappingReferenceIndices[vindex];

                // 座標書き込み
                meshLocalPositions[windex] = mappingPositions[vindex];

                // 法線書き込み
                meshLocalNormals[windex] = mappingNormals[vindex];
            }
        }

        [BurstCompile]
        struct UpdatePositionNormalTangentJob : IJobParallelFor
        {
            public int startIndex;

            [NativeDisableParallelForRestriction]
            [Unity.Collections.WriteOnly]
            public NativeArray<float3> meshLocalPositions;
            [NativeDisableParallelForRestriction]
            [Unity.Collections.WriteOnly]
            public NativeArray<float3> meshLocalNormals;
            [NativeDisableParallelForRestriction]
            //[Unity.Collections.WriteOnly]
            public NativeArray<float4> meshLocalTangents;

            // mapping mesh
            [Unity.Collections.ReadOnly]
            public NativeArray<int> mappingReferenceIndices;
            [Unity.Collections.ReadOnly]
            public NativeArray<VertexAttribute> mappingAttributes;
            [Unity.Collections.ReadOnly]
            public NativeArray<float3> mappingPositions;
            [Unity.Collections.ReadOnly]
            public NativeArray<float3> mappingNormals;
            [Unity.Collections.ReadOnly]
            public NativeArray<float3> mappingTangents;

            public void Execute(int index)
            {
                int vindex = index + startIndex;

                // 無効頂点なら書き込まない
                var attr = mappingAttributes[vindex];
                if (attr.IsInvalid())
                    return;

                // 固定も書き込まない
                if (attr.IsFixed())
                    return;

                // 書き込む頂点インデックス
                int windex = mappingReferenceIndices[vindex];

                // 座標書き込み
                meshLocalPositions[windex] = mappingPositions[vindex];

                // 法線書き込み
                meshLocalNormals[windex] = mappingNormals[vindex];

                // 接線書き込み
                var tan = meshLocalTangents[windex];
                meshLocalTangents[windex] = new float4(mappingTangents[vindex], tan.w);
            }
        }

        /// <summary>
        /// メッシュのボーンウエイト書き込み
        /// </summary>
        /// <param name="vmesh"></param>
        /// <param name="jobHandle"></param>
        /// <returns></returns>
        internal JobHandle UpdateBoneWeight(DataChunk mappingChunk, JobHandle jobHandle = default)
        {
            //Debug.Log($"UpdateBoneWeight [{Name}] UseCustomMesh:{UseCustomMesh}, ModifyBoneWeight:{flag.IsSet(Flag_ModifyBoneWeight)}");

            if (UseCustomMesh == false)
                return jobHandle;

            // ボーンウエイトの差分書き換え
            if (HasBoneWeight && flag.IsSet(Flag_ModifyBoneWeight))
            {
                var vm = MagicaManager.VMesh;

                var job = new UpdateBoneWeightJob2()
                {
                    startIndex = mappingChunk.startIndex,
                    centerBoneWeight = centerBoneWeight,
                    meshBoneWeights = boneWeights,

                    mappingReferenceIndices = vm.mappingReferenceIndices.GetNativeArray(),
                    mappingAttributes = vm.mappingAttributes.GetNativeArray(),
                };
                jobHandle = job.Schedule(mappingChunk.dataLength, 32, jobHandle);

                flag.SetBits(Flag_ChangeBoneWeight, true);

                //Debug.Log($"UpdateBoneWeightJob2");
            }

            return jobHandle;
        }

        [BurstCompile]
        struct UpdateBoneWeightJob2 : IJobParallelFor
        {
            public int startIndex;
            public BoneWeight centerBoneWeight;

            [NativeDisableParallelForRestriction]
            [Unity.Collections.WriteOnly]
            public NativeArray<BoneWeight> meshBoneWeights;

            // mapping mesh
            [Unity.Collections.ReadOnly]
            public NativeArray<int> mappingReferenceIndices;
            [Unity.Collections.ReadOnly]
            public NativeArray<VertexAttribute> mappingAttributes;

            public void Execute(int index)
            {
                int vindex = index + startIndex;

                // 無効頂点なら書き込まない
                var attr = mappingAttributes[vindex];
                if (attr.IsInvalid())
                    return;

                // 固定も書き込まない
                if (attr.IsFixed())
                    return;

                // 書き込む頂点インデックス
                int windex = mappingReferenceIndices[vindex];

                // 使用頂点のウエイトはcenterTransform100%で書き込む
                meshBoneWeights[windex] = centerBoneWeight;
            }
        }

        //=========================================================================================
        public override string ToString()
        {
            StringBuilder sb = new StringBuilder();

            sb.Append($">>> [{Name}] ref:{ReferenceCount}, useProcess:{useProcessSet.Count}, HasSkinnedMesh:{HasSkinnedMesh}, HasBoneWeight:{HasBoneWeight}");
            sb.AppendLine();

            return sb.ToString();
        }
    }
}

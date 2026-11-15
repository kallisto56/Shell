#include "pch.h"
#include "JunoInternal.h"

JUNO_API void JunoDraw(JunoDevice* pDevice, c_uint vertexCount, c_uint startVertex)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->Draw(vertexCount, startVertex);
}

JUNO_API void JunoDrawIndexed(JunoDevice* pDevice, c_uint indexCount, c_uint startIndex, c_int baseVertex)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->DrawIndexed(indexCount, startIndex, baseVertex);
}

JUNO_API void JunoDrawInstanced(JunoDevice* pDevice, c_uint vertexCountPerInstance, c_uint instanceCount, c_uint startVertex, c_uint startInstance)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->DrawInstanced(vertexCountPerInstance, instanceCount, startVertex, startInstance);
}

JUNO_API void JunoDrawIndexedInstanced(JunoDevice* pDevice, c_uint indexCountPerInstance, c_uint instanceCount, c_uint startIndex, c_int baseVertex, c_uint startInstance)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->DrawIndexedInstanced(indexCountPerInstance, instanceCount, startIndex, baseVertex, startInstance);
}

JUNO_API void JunoDispatch(JunoDevice* pDevice, c_uint groupsX, c_uint groupsY, c_uint groupsZ)
{
	JUNO_ASSERT(pDevice != nullptr);
	pDevice->mContext->Dispatch(groupsX, groupsY, groupsZ);
}

namespace Shell.Layout;

using System;
using System.Collections;

// Resolved column / row sizes of one grid layout pass.
class GridLayout
{
	public List<float> mColumns = new .() ~ delete _;
	public List<float> mRows = new .() ~ delete _;

	public float mWidth
	{
		get
		{
			float sum = 0;
			for (let c in mColumns) sum += c;
			return sum;
		}
	}

	public float mHeight
	{
		get
		{
			float sum = 0;
			for (let r in mRows) sum += r;
			return sum;
		}
	}

	public float ColumnStart(int column)
	{
		float sum = 0;
		for (int i < Math.Min(column, mColumns.Count)) sum += mColumns[i];
		return sum;
	}

	public float RowStart(int row)
	{
		float sum = 0;
		for (int i < Math.Min(row, mRows.Count)) sum += mRows[i];
		return sum;
	}

	public float ColumnsWidth(int column, int span)
	{
		float sum = 0;
		for (int i = column; i < Math.Min(column + span, mColumns.Count); i++) sum += mColumns[i];
		return sum;
	}

	public float RowsHeight(int row, int span)
	{
		float sum = 0;
		for (int i = row; i < Math.Min(row + span, mRows.Count); i++) sum += mRows[i];
		return sum;
	}
}

// This file contains the IO functions related to a dataframe.
// Each format has 8 functions related. They do the following:
//
// - dump: dump a dataframe to a string using the given format (like in a CSV string).
// - load: load a dataframe from a given string (let's say, from a CSV string).
// - from: reads a dataframe from a file that is encoded in a given format.
// - to: writes a dataframe to a file in a given format.
//
// Today we have the following formats: CSV, NDJSON, Parquet, Apache Arrow and Apache Arrow Stream.
//
use polars::prelude::*;

use rustler::{Binary, Env, NewBinary};
use std::convert::TryFrom;
use std::fs::File;
use std::io::{BufReader, BufWriter, Cursor};
use std::result::Result;

use crate::dataframe::normalize_numeric_dtypes;
use crate::datatypes::ExParquetCompression;
use crate::{ExDataFrame, ExplorerError};

fn finish_reader<R>(reader: impl SerReader<R>) -> Result<ExDataFrame, ExplorerError>
where
    R: polars::io::mmap::MmapBytesReader,
{
    let mut df = reader.finish()?;

    let normalized_df = normalize_numeric_dtypes(&mut df)?;

    Ok(ExDataFrame::new(normalized_df))
}

// ============ CSV ============ //

#[rustler::nif(schedule = "DirtyIo")]
#[allow(clippy::too_many_arguments)]
pub fn df_from_csv(
    filename: &str,
    infer_schema_length: Option<usize>,
    has_header: bool,
    stop_after_n_rows: Option<usize>,
    skip_rows: usize,
    projection: Option<Vec<usize>>,
    delimiter_as_byte: u8,
    do_rechunk: bool,
    column_names: Option<Vec<String>>,
    dtypes: Option<Vec<(&str, &str)>>,
    encoding: &str,
    null_char: String,
    parse_dates: bool,
) -> Result<ExDataFrame, ExplorerError> {
    let encoding = match encoding {
        "utf8-lossy" => CsvEncoding::LossyUtf8,
        _ => CsvEncoding::Utf8,
    };

    let schema: Option<Schema> = match dtypes {
        Some(dtypes) => Some(schema_from_dtypes_pairs(dtypes)?),

        None => None,
    };

    let reader = CsvReader::from_path(filename)?
        .infer_schema(infer_schema_length)
        .has_header(has_header)
        .with_parse_dates(parse_dates)
        .with_n_rows(stop_after_n_rows)
        .with_delimiter(delimiter_as_byte)
        .with_skip_rows(skip_rows)
        .with_projection(projection)
        .with_rechunk(do_rechunk)
        .with_encoding(encoding)
        .with_columns(column_names)
        .with_dtypes(schema.as_ref())
        .with_null_values(Some(NullValues::AllColumns(vec![null_char])));

    finish_reader(reader)
}

pub fn schema_from_dtypes_pairs(dtypes: Vec<(&str, &str)>) -> Result<Schema, ExplorerError> {
    let mut schema = Schema::new();
    for (name, dtype_str) in dtypes {
        let dtype = dtype_from_str(dtype_str)?;
        schema.with_column(name.to_string(), dtype)
    }
    Ok(schema)
}

fn dtype_from_str(dtype: &str) -> Result<DataType, ExplorerError> {
    match dtype {
        "binary" => Ok(DataType::Binary),
        "bool" => Ok(DataType::Boolean),
        "cat" => Ok(DataType::Categorical(None)),
        "date" => Ok(DataType::Date),
        "datetime[ms]" => Ok(DataType::Datetime(TimeUnit::Milliseconds, None)),
        "datetime[ns]" => Ok(DataType::Datetime(TimeUnit::Nanoseconds, None)),
        "datetime[μs]" => Ok(DataType::Datetime(TimeUnit::Microseconds, None)),
        "f64" => Ok(DataType::Float64),
        "i64" => Ok(DataType::Int64),
        "str" => Ok(DataType::Utf8),
        _ => Err(ExplorerError::Internal("Unrecognised datatype".into())),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn df_to_csv(
    data: ExDataFrame,
    filename: &str,
    has_headers: bool,
    delimiter: u8,
) -> Result<(), ExplorerError> {
    let file = File::create(filename)?;
    let mut buf_writer = BufWriter::new(file);
    CsvWriter::new(&mut buf_writer)
        .has_header(has_headers)
        .with_delimiter(delimiter)
        .finish(&mut data.clone_inner())?;
    Ok(())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_dump_csv(
    env: Env,
    data: ExDataFrame,
    has_headers: bool,
    delimiter: u8,
) -> Result<Binary, ExplorerError> {
    let mut buf = vec![];

    CsvWriter::new(&mut buf)
        .has_header(has_headers)
        .with_delimiter(delimiter)
        .finish(&mut data.clone_inner())?;

    let mut values_binary = NewBinary::new(env, buf.len());
    values_binary.copy_from_slice(&buf);

    Ok(values_binary.into())
}

#[rustler::nif(schedule = "DirtyCpu")]
#[allow(clippy::too_many_arguments)]
pub fn df_load_csv(
    binary: Binary,
    infer_schema_length: Option<usize>,
    has_header: bool,
    stop_after_n_rows: Option<usize>,
    skip_rows: usize,
    projection: Option<Vec<usize>>,
    delimiter_as_byte: u8,
    do_rechunk: bool,
    column_names: Option<Vec<String>>,
    dtypes: Option<Vec<(&str, &str)>>,
    encoding: &str,
    null_char: String,
    parse_dates: bool,
) -> Result<ExDataFrame, ExplorerError> {
    let encoding = match encoding {
        "utf8-lossy" => CsvEncoding::LossyUtf8,
        _ => CsvEncoding::Utf8,
    };

    let schema: Option<Schema> = match dtypes {
        Some(dtypes) => Some(schema_from_dtypes_pairs(dtypes)?),

        None => None,
    };

    let cursor = Cursor::new(binary.as_slice());

    let reader = CsvReader::new(cursor)
        .infer_schema(infer_schema_length)
        .has_header(has_header)
        .with_parse_dates(parse_dates)
        .with_n_rows(stop_after_n_rows)
        .with_delimiter(delimiter_as_byte)
        .with_skip_rows(skip_rows)
        .with_projection(projection)
        .with_rechunk(do_rechunk)
        .with_encoding(encoding)
        .with_columns(column_names)
        .with_dtypes(schema.as_ref())
        .with_null_values(Some(NullValues::AllColumns(vec![null_char])));

    finish_reader(reader)
}

// ============ Parquet ============ //

#[rustler::nif(schedule = "DirtyIo")]
pub fn df_from_parquet(filename: &str) -> Result<ExDataFrame, ExplorerError> {
    let file = File::open(filename)?;
    let buf_reader = BufReader::new(file);
    let reader = ParquetReader::new(buf_reader);

    finish_reader(reader)
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn df_to_parquet(
    data: ExDataFrame,
    filename: &str,
    ex_compression: ExParquetCompression,
) -> Result<(), ExplorerError> {
    let file = File::create(filename)?;
    let mut buf_writer = BufWriter::new(file);

    let compression = ParquetCompression::try_from(ex_compression)?;

    ParquetWriter::new(&mut buf_writer)
        .with_compression(compression)
        .finish(&mut data.clone_inner())?;
    Ok(())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_dump_parquet(
    env: Env,
    data: ExDataFrame,
    ex_compression: ExParquetCompression,
) -> Result<Binary, ExplorerError> {
    let mut buf = vec![];

    let compression = ParquetCompression::try_from(ex_compression)?;

    ParquetWriter::new(&mut buf)
        .with_compression(compression)
        .finish(&mut data.clone_inner())?;

    let mut values_binary = NewBinary::new(env, buf.len());
    values_binary.copy_from_slice(&buf);

    Ok(values_binary.into())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_load_parquet(binary: Binary) -> Result<ExDataFrame, ExplorerError> {
    let cursor = Cursor::new(binary.as_slice());
    let reader = ParquetReader::new(cursor);

    finish_reader(reader)
}

// ============ IPC ============ //

#[rustler::nif(schedule = "DirtyIo")]
pub fn df_from_ipc(
    filename: &str,
    columns: Option<Vec<String>>,
    projection: Option<Vec<usize>>,
) -> Result<ExDataFrame, ExplorerError> {
    let file = File::open(filename)?;
    let buf_reader = BufReader::new(file);
    let reader = IpcReader::new(buf_reader)
        .with_columns(columns)
        .with_projection(projection);

    finish_reader(reader)
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn df_to_ipc(
    data: ExDataFrame,
    filename: &str,
    compression: Option<&str>,
) -> Result<(), ExplorerError> {
    // Select the compression algorithm.
    let compression = match compression {
        Some("lz4") => Some(IpcCompression::LZ4),
        Some("zstd") => Some(IpcCompression::ZSTD),
        _ => None,
    };

    let file = File::create(filename)?;
    let mut buf_writer = BufWriter::new(file);
    IpcWriter::new(&mut buf_writer)
        .with_compression(compression)
        .finish(&mut data.clone_inner())?;
    Ok(())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_dump_ipc<'a>(
    env: Env<'a>,
    data: ExDataFrame,
    compression: Option<&str>,
) -> Result<Binary<'a>, ExplorerError> {
    let mut buf = vec![];

    // Select the compression algorithm.
    let compression = match compression {
        Some("lz4") => Some(IpcCompression::LZ4),
        Some("zstd") => Some(IpcCompression::ZSTD),
        _ => None,
    };

    IpcWriter::new(&mut buf)
        .with_compression(compression)
        .finish(&mut data.clone_inner())?;

    let mut values_binary = NewBinary::new(env, buf.len());
    values_binary.copy_from_slice(&buf);

    Ok(values_binary.into())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_load_ipc(
    binary: Binary,
    columns: Option<Vec<String>>,
    projection: Option<Vec<usize>>,
) -> Result<ExDataFrame, ExplorerError> {
    let cursor = Cursor::new(binary.as_slice());
    let reader = IpcReader::new(cursor)
        .with_columns(columns)
        .with_projection(projection);

    finish_reader(reader)
}

// ============ IPC Streaming ============ //

#[rustler::nif(schedule = "DirtyIo")]
pub fn df_from_ipc_stream(
    filename: &str,
    columns: Option<Vec<String>>,
    projection: Option<Vec<usize>>,
) -> Result<ExDataFrame, ExplorerError> {
    let file = File::open(filename)?;
    let buf_reader = BufReader::new(file);
    let reader = IpcStreamReader::new(buf_reader)
        .with_columns(columns)
        .with_projection(projection);

    finish_reader(reader)
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn df_to_ipc_stream(
    data: ExDataFrame,
    filename: &str,
    compression: Option<&str>,
) -> Result<(), ExplorerError> {
    // Select the compression algorithm.
    let compression = match compression {
        Some("lz4") => Some(IpcCompression::LZ4),
        Some("zstd") => Some(IpcCompression::ZSTD),
        _ => None,
    };

    let mut file = File::create(filename).expect("could not create file");
    IpcStreamWriter::new(&mut file)
        .with_compression(compression)
        .finish(&mut data.clone_inner())?;
    Ok(())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_dump_ipc_stream<'a>(
    env: Env<'a>,
    data: ExDataFrame,
    compression: Option<&str>,
) -> Result<Binary<'a>, ExplorerError> {
    let mut buf = vec![];

    // Select the compression algorithm.
    let compression = match compression {
        Some("lz4") => Some(IpcCompression::LZ4),
        Some("zstd") => Some(IpcCompression::ZSTD),
        _ => None,
    };

    IpcStreamWriter::new(&mut buf)
        .with_compression(compression)
        .finish(&mut data.clone_inner())?;

    let mut values_binary = NewBinary::new(env, buf.len());
    values_binary.copy_from_slice(&buf);

    Ok(values_binary.into())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_load_ipc_stream(
    binary: Binary,
    columns: Option<Vec<String>>,
    projection: Option<Vec<usize>>,
) -> Result<ExDataFrame, ExplorerError> {
    let cursor = Cursor::new(binary.as_slice());
    let reader = IpcStreamReader::new(cursor)
        .with_columns(columns)
        .with_projection(projection);

    finish_reader(reader)
}

// ============ NDJSON ============ //

#[cfg(not(any(target_arch = "arm", target_arch = "riscv64")))]
#[rustler::nif(schedule = "DirtyIo")]
pub fn df_from_ndjson(
    filename: &str,
    infer_schema_length: Option<usize>,
    batch_size: usize,
) -> Result<ExDataFrame, ExplorerError> {
    let file = File::open(filename)?;
    let buf_reader = BufReader::new(file);
    let reader = JsonReader::new(buf_reader)
        .with_json_format(JsonFormat::JsonLines)
        .with_batch_size(batch_size)
        .infer_schema_len(infer_schema_length);

    finish_reader(reader)
}

#[cfg(not(any(target_arch = "arm", target_arch = "riscv64")))]
#[rustler::nif(schedule = "DirtyIo")]
pub fn df_to_ndjson(data: ExDataFrame, filename: &str) -> Result<(), ExplorerError> {
    let file = File::create(filename)?;
    let mut buf_writer = BufWriter::new(file);

    JsonWriter::new(&mut buf_writer)
        .with_json_format(JsonFormat::JsonLines)
        .finish(&mut data.clone_inner())?;
    Ok(())
}

#[cfg(not(any(target_arch = "arm", target_arch = "riscv64")))]
#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_dump_ndjson(env: Env, data: ExDataFrame) -> Result<Binary, ExplorerError> {
    let mut buf = vec![];

    JsonWriter::new(&mut buf)
        .with_json_format(JsonFormat::JsonLines)
        .finish(&mut data.clone_inner())?;

    let mut values_binary = NewBinary::new(env, buf.len());
    values_binary.copy_from_slice(&buf);

    Ok(values_binary.into())
}

#[cfg(not(any(target_arch = "arm", target_arch = "riscv64")))]
#[rustler::nif(schedule = "DirtyCpu")]
pub fn df_load_ndjson(
    binary: Binary,
    infer_schema_length: Option<usize>,
    batch_size: usize,
) -> Result<ExDataFrame, ExplorerError> {
    let cursor = Cursor::new(binary.as_slice());
    let reader = JsonReader::new(cursor)
        .with_json_format(JsonFormat::JsonLines)
        .with_batch_size(batch_size)
        .infer_schema_len(infer_schema_length);

    finish_reader(reader)
}

// ============ ARM 32 specifics ============ //

#[cfg(any(target_arch = "arm", target_arch = "riscv64"))]
#[rustler::nif]
pub fn df_from_ndjson(
    _filename: &str,
    _infer_schema_length: Option<usize>,
    _batch_size: usize,
) -> Result<ExDataFrame, ExplorerError> {
    Err(ExplorerError::Other(format!(
        "NDJSON parsing is not enabled for this machine"
    )))
}

#[cfg(any(target_arch = "arm", target_arch = "riscv64"))]
#[rustler::nif]
pub fn df_to_ndjson(_data: ExDataFrame, _filename: &str) -> Result<(), ExplorerError> {
    Err(ExplorerError::Other(format!(
        "NDJSON writing is not enabled for this machine"
    )))
}

#[cfg(any(target_arch = "arm", target_arch = "riscv64"))]
#[rustler::nif]
pub fn df_dump_ndjson(_data: ExDataFrame) -> Result<Binary<'static>, ExplorerError> {
    Err(ExplorerError::Other(format!(
        "NDJSON dumping is not enabled for this machine"
    )))
}

#[cfg(any(target_arch = "arm", target_arch = "riscv64"))]
#[rustler::nif]
pub fn df_load_ndjson(
    _binary: Binary,
    _infer_schema_length: Option<usize>,
    _batch_size: usize,
) -> Result<ExDataFrame, ExplorerError> {
    Err(ExplorerError::Other(format!(
        "NDJSON loading is not enabled for this machine"
    )))
}

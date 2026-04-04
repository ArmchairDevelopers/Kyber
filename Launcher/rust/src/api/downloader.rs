use flutter_rust_bridge::frb;

use crate::frb_generated::{RustAutoOpaque, StreamSink};

use maxima::content::{
    downloader::ZipDownloader,
    zip::{CompressionType, ZipFileEntry},
};

#[frb(opaque)]
pub struct DownloaderHandle(ZipDownloader);

#[frb(non_opaque)]
#[derive(Clone, Debug)]
pub struct ZipEntryInfo {
    pub name: String,
    pub compressed_size: i64,
    pub uncompressed_size: i64,
    pub compression: String,
    pub data_offset: i64,
    pub crc32: u32,
}

fn entry_to_info(e: &ZipFileEntry) -> ZipEntryInfo {
    ZipEntryInfo {
        name: e.name().to_string(),
        compressed_size: *e.compressed_size(),
        uncompressed_size: *e.uncompressed_size(),
        compression: match e.compression_type() {
            CompressionType::None => "none".to_string(),
            CompressionType::Deflate => "deflate".to_string(),
            other => format!("{other:?}"),
        },
        data_offset: *e.data_offset(),
        crc32: *e.crc32(),
    }
}

pub async fn downloader_create(
    id: String,
    zip_url: String,
    output_dir: String,
) -> Result<RustAutoOpaque<DownloaderHandle>, String> {
    let dl = ZipDownloader::new(&id, &zip_url, output_dir)
        .await
        .map_err(|e| e.to_string())?;

    Ok(RustAutoOpaque::new(DownloaderHandle(dl)))
}

pub async fn downloader_get_id(d: RustAutoOpaque<DownloaderHandle>) -> String {
    d.read().await.0.id().to_string()
}

pub async fn downloader_list_entries(d: RustAutoOpaque<DownloaderHandle>) -> Vec<ZipEntryInfo> {
    d.read().await.0.manifest()
        .entries()
        .iter()
        .map(entry_to_info)
        .collect()
}

fn find_entry<'a>(d: &'a ZipDownloader, entry_name: &str) -> Result<&'a ZipFileEntry, String> {
    d.manifest()
        .entries()
        .iter()
        .find(|e| e.name() == entry_name)
        .ok_or_else(|| format!("Zip entry not found: {entry_name}"))
}

pub async fn downloader_download_entry_by_name(
    d: RustAutoOpaque<DownloaderHandle>,
    entry_name: String,
    progress: Option<StreamSink<i32>>,
) -> Result<i32, String> {
    let inner: &ZipDownloader = &d.read().await.0;

    let entry = find_entry(inner, &entry_name)?;

    let callback = progress.map(|sink| {
        Box::new(move |n: usize| {
            let _ = sink.add(n as i32);
        }) as Box<dyn Fn(usize) + Send + Sync>
    });

    let written = inner
        .download_single_file(entry, callback)
        .await
        .map_err(|e| e.to_string())?;

    Ok(written as i32)
}

pub async fn downloader_read_entry_bytes(
    d: RustAutoOpaque<DownloaderHandle>,
    entry_name: String,
    length: i64,
) -> Result<Vec<u8>, String> {
    let inner: &ZipDownloader = &d.read().await.0;
    let entry = find_entry(inner, &entry_name)?;

    let bytes = inner
        .read_zip_entry_bytes(entry, length as u64)
        .await
        .map_err(|e| e.to_string())?;

    Ok(bytes.to_vec())
}

pub fn downloader_dispose(_d: RustAutoOpaque<DownloaderHandle>) {
}
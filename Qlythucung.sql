create database qlythucung;
go
use qlythucung;

go

create table khachhang
(
	makh nchar(9) primary key,
	tenkh nvarchar(39),
	diachi nvarchar(99),
	sdt nchar(10),
	sohd nchar(3)
)

create table thucung
(
	mathu nchar(9) Not null,
	maloai nchar(9),
	sokg dec(9,2),
	makh nchar(9),
	ngaygui datetime Not null,
	ngaytra datetime,
	madv nchar(9),
	manv nchar(9)
)
alter table thucung add constraint pk_thucung primary key (mathu, ngaygui)

create table loai
(
	maloai nchar(9) primary key,
	tenloai nvarchar(20)
)

create table dichvu
(
	madv nchar(9) primary key,
	tendv nvarchar(100),
	giatien nchar(20)
)

create table nhanvien
(
	manv nchar(9) primary key,
	honv nvarchar(9),
	tenlot nvarchar(19),
	tennv nvarchar(9),
	ngaysinh datetime,
	gioitinh nvarchar(9),
	diachi nvarchar(99),
	sdt nchar(10),
	ma_nql nchar(9)
)

go

-- Tham chiếu khóa ngoại
alter table thucung
add  constraint fk_khachhang foreign key(makh)
references khachhang(makh);

alter table thucung
add  constraint fk_dichvu foreign key(madv)
references dichvu(madv);

alter table thucung
add  constraint fk_loai foreign key(maloai)
references loai(maloai);

alter table thucung
add  constraint fk_nhanvien foreign key(manv)
references nhanvien(manv);

alter table nhanvien
add  constraint fk_ngql foreign key(ma_nql)
references nhanvien(manv);

go

-- Function
	-- Tạo hàm kiểm tra các mã ngoại nhập vào bảng thú cưng có thích hợp hay không
create function check_thucung (
    @makh nchar(9), @madv nchar(9), @maloai nchar(9), @manv nchar(9)
)
returns VARCHAR(5)
as
begin
    if exists (select * from khachhang WHERE makh = @makh) and
		exists (select * from loai WHERE maloai = @maloai) and
		exists (select * from dichvu WHERE madv = @madv) and
		exists (select * from nhanvien WHERE manv = @manv)
        return 'True'
    return 'False'
end

go

	-- Kiểm tra mã khách hàng có tồn tại không
create function check_kh ( @makh nchar(9) )
returns VARCHAR(5)
as
begin
    if exists(select makh from khachhang where makh=@makh)
        return 'True'
    return 'False'
end

go

	-- Kiểm tra mã dịch vụ có tồn tại không
create function check_dv ( @madv nchar(9) )
returns VARCHAR(5)
as
begin
    if exists(select madv from dichvu where madv=@madv)
        return 'True'
    return 'False'
end

go

	-- Kiểm tra mã nhân viên có tồn tại không
create function check_nv ( @manv nchar(9) )
returns VARCHAR(5)
as
begin
    if exists(select manv from nhanvien where manv=@manv)
        return 'True'
    return 'False'
end

go

	-- Kiểm tra mã người quản lý có tồn tại không
create function check_nql ( @manql nchar(9) )
returns VARCHAR(5)
as
begin
    if exists(select ma_nql from nhanvien where ma_nql=@manql)
        return 'True'
    return 'False'
end

go

	-- Kiểm tra mã thú cưng có tồn tại không
create function check_tc ( @matc nchar(9), @ngaygui datetime )
returns VARCHAR(5)
as
begin
    if exists(select * from thucung where mathu=@matc and ngaygui=@ngaygui)
        return 'True'
    return 'False'
end

go

	-- Kiểm tra mã loài có tồn tại không
create function check_loai ( @maloai nchar(9) )
returns VARCHAR(5)
as
begin
    if exists(select * from loai where maloai=@maloai )
        return 'True'
    return 'False'
end

go

	-- Tạo hàm (nhận vào mã dịch vụ, số kí, số ngày gửi) trả về tổng tiền của hóa đơn
create function tong_hoadon (
    @madv nchar(9), @sokg decimal(9,2), @songay int
)
returns decimal(30,2)
as
begin
    declare @giatien nchar(20);
	set @giatien = (select giatien from dichvu dv where dv.madv = @madv)
	if (@madv = 'SCB' or @madv = 'SSCB') 
		begin
		if (@songay >= 3) 
			return ((@giatien + @songay*75000)*@sokg/2)
		return (@giatien * @sokg/2)
		end
	return (@giatien * @sokg/2)
end

go

	-- Tạo hàm trả về bảng hóa đơn
create function dbo.tHoadon()
returns table
as
return
select trim(tc.mathu) + '-' + Convert(nchar,Convert(int,tc.ngaygui)) mahd, tc.makh, tc.madv, tc.manv, tc.sokg , Convert(varchar,tc.ngaygui,105) ngaygui, Convert(varchar,tc.ngaytra,105) ngaytra, dbo.tong_hoadon(tc.madv, tc.sokg, Convert(int,ngaytra - ngaygui ,105)) tongtien
from thucung tc, khachhang kh, dichvu dv, nhanvien nv
where (tc.makh = kh.makh and tc.madv = dv.madv and tc.manv = nv.manv)

go

	-- Tạo hàm (nhận vào tháng, năm và lương cứng ) trả về bảng lương của toàn bộ nhân viên trong tháng lương đó
create function dbo.tBangluong(@thang nchar(2), @nam nchar(4), @luongcung decimal(30,2))
returns table
as
return
select bl.manv N'Mã nhân viên', nv.honv + ' ' + nv.tenlot + ' ' + nv.tennv N'Nhân Viên', trim(@thang) + '/' + @nam N'Tháng Lương',  @luongcung N'Lương cứng', bl.tc N'Tiền công theo hóa đơn (15%)', bl.tl N'Tổng Lương'
from (
select nv.manv, bl1.tc, @luongcung + isnull( bl1.tc, 0 ) tl
from nhanvien nv
left join
(
	select distinct manv, sum(Convert(decimal(30,2),tongtien*15/100)) tc
	from dbo.tHoadon()
	where (month(ngaygui) = @thang and year(ngaygui) = @nam)
	group by manv
) bl1
on (nv.manv = bl1.manv)
) bl, nhanvien nv
where (bl.manv = nv.manv)

go

-- Store procedure

	-- Khách hàng
		-- Thêm dữ liệu khách hàng
create procedure insert_kh (@makh nchar(9), @tenkh nvarchar(39), @diachi nvarchar(99), @sdt nchar(10))
as
begin			
	if(dbo.check_kh(@makh) = 'True')
	begin
		print N'Khách hàng '+ trim(@makh) +N' đã tồn tại'
	end
	else
	begin try
		insert into khachhang(makh, tenkh, diachi, sdt)
		values (@makh, @tenkh, @diachi, @sdt)
		print N'Thêm khách hàng '+ trim(@makh) +N' thành công'
	end try
	begin catch
		print N'Thêm khách hàng '+ trim(@makh) +N' không thành công. Vui lòng thử lại.'
	end catch
end

go

		-- Xóa khách hàng
create procedure delete_kh (@makh nchar(9))
as
begin
	if (dbo.check_kh(@makh) = 'True')
	begin try
		delete from khachhang
		where khachhang.makh = @makh
		print N'Xóa thành công khách hàng '+ trim(@makh)
	end try
	begin catch
		print N'Không thể xóa khách hàng '+ trim(@makh) + N'. (Có dữ liệu thú cưng liên quan đến khách hàng này)'
	end catch
	else
	begin
		print N'Khách hàng '+ trim(@makh) + N' không tồn tại.'
	end
end

go

		-- Cập nhật số điện thoại
create procedure update_kh_sodt(@makh char(9),@sdt nchar(10))
as
begin
	if(dbo.check_kh(@makh) = 'True')
	begin try
		update khachhang
		set sdt=@sdt
		where makh=@makh
		print N'Cập nhật số điện thoại cho khách hàng '+ trim(@makh) +N' thành công'
	end try
	begin catch
		print N'Cập nhật số điện thoại cho khách hàng '+ trim(@makh) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Khách hàng '+ trim(@makh) +N' không tồn tại'
	end
end

go

		-- Cập nhật địa chỉ
create procedure update_kh_diachi(@makh char(9),@diachi nvarchar(99))
as
begin
	if(dbo.check_kh(@makh) = 'True')
	begin try
		update khachhang
		set diachi=@diachi
		where makh=@makh
		print N'Cập nhật địa chỉ cho khách hàng '+ trim(@makh) +N' thành công'
	end try
	begin catch
		print N'Cập nhật địa chỉ cho khách hàng '+ trim(@makh) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Khách hàng '+ trim(@makh) +N' không tồn tại'
	end
end

go

	-- Dịch vụ
		-- Thêm dữ liệu dịch vụ
create procedure insert_dv (@madv nchar(9), @tendv nvarchar(100), @giatien nchar(20))
as
begin			
	if(dbo.check_dv(@madv) = 'True')
	begin
		print N'Dịch vụ '+ trim(@madv) +N' đã tồn tại'
	end
	else
	begin try
		insert into dichvu(madv, tendv, giatien)
		values (@madv, @tendv, @giatien)
		print N'Thêm dịch vụ '+ trim(@madv) +N' thành công'
	end try
	begin catch
		print N'Thêm dịch vụ '+ trim(@madv) +N' không thành công. Vui lòng thử lại.'
	end catch
end

go

		-- Xóa dịch vụ
create procedure delete_dv (@madv nchar(9))
as
begin
	if (dbo.check_dv(@madv) = 'True')
	begin try
		delete from dichvu
		where dichvu.madv = @madv
		print N'Xóa thành công dịch vụ '+ trim(@madv)
	end try
	begin catch
		print N'Không thể xóa dịch vụ '+ trim(@madv) + N'. (Có dữ liệu thú cưng liên quan đến dịch vụ này)'
	end catch
	else
	begin
		print N'Dịch vụ '+ trim(@madv) + N' không tồn tại.'
	end
end

go

		-- Cập nhật giá tiền
create procedure update_dv_giatien (@madv char(9),@giatien nchar(20))
as
begin
	if(dbo.check_dv(@madv) = 'True')
	begin try
		update dichvu
		set giatien=@giatien
		where madv=@madv
		print N'Cập nhật giá tiền cho dịch vụ '+ trim(@madv) +N' thành công'
	end try
	begin catch
		print N'Cập nhật giá tiền cho dịch vụ '+ trim(@madv) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Dịch vụ '+ trim(@madv) +N' không tồn tại'
	end
end

go

		-- Cập nhật tên dịch vụ
create procedure update_dv_tendv (@madv char(9),@tendv nvarchar(100))
as
begin
	if(dbo.check_dv(@madv) = 'True')
	begin try
		update dichvu
		set tendv=@tendv
		where madv=@madv
		print N'Cập nhật tên cho dịch vụ '+ trim(@madv) +N' thành công'
	end try
	begin catch
		print N'Cập nhật tên cho dịch vụ '+ trim(@madv) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Dịch vụ '+ trim(@madv) +N' không tồn tại'
	end
end

go

	-- Nhân viên
			-- Thêm dữ liệu nhân viên
create procedure insert_nv (@manv nchar(9), @honv nvarchar(9), @tenlot nvarchar(19), @tennv nvarchar(9), @ngaysinh datetime, @gioitinh nvarchar(9), @diachi nvarchar(99), @sdt nchar(10), @manql nchar(9))
as
begin			
	if(dbo.check_nv(@manv) = 'True')
	begin
		print N'Nhân viên '+ trim(@manv) +N' đã tồn tại'
	end
	else
	begin try
		insert into nhanvien(manv, honv, tenlot, tennv, ngaysinh, gioitinh, diachi, sdt, ma_nql)
		values (@manv, @honv, @tenlot, @tennv, @ngaysinh, @gioitinh, @diachi, @sdt, @manql)
		print N'Thêm nhân viên '+ trim(@manv) +N' thành công'
	end try
	begin catch
		print N'Thêm nhân viên '+ trim(@manv) +N' không thành công. Vui lòng thử lại.'
	end catch
end

go
		
		-- Xóa nhân viên
create procedure delete_nv (@manv nchar(9))
as
begin
	if (dbo.check_nv(@manv) = 'True')
	begin try
		delete from nhanvien
		where nhanvien.manv = @manv
		print N'Xóa thành công nhân viên '+ trim(@manv)
	end try
	begin catch
		print N'Không thể xóa nhân viên '+ trim(@manv) + N'. (Có dữ liệu thú cưng liên quan đến nhân viên này)'
	end catch
	else
	begin
		print N'Nhân viên '+ trim(@manv) + N' không tồn tại.'
	end
end

go

		-- Cập nhật số điện thoại
create procedure update_nv_sodt(@manv char(9),@sdt nchar(10))
as
begin
	if(dbo.check_nv(@manv) = 'True')
	begin try
		update nhanvien
		set sdt=@sdt
		where manv=@manv
		print N'Cập nhật số điện thoại cho nhân viên '+ trim(@manv) +N' thành công'
	end try
	begin catch
		print N'Cập nhật số điện thoại cho nhân viên '+ trim(@manv) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Nhân viên '+ trim(@manv) +N' không tồn tại'
	end
end

go

		-- Cập nhật địa chỉ
create procedure update_nv_diachi(@manv char(9),@diachi nvarchar(99))
as
begin
	if(dbo.check_nv(@manv) = 'True')
	begin try
		update nhanvien
		set diachi=@diachi
		where manv=@manv
		print N'Cập nhật địa chỉ cho nhân viên '+ trim(@manv) +N' thành công'
	end try
	begin catch
		print N'Cập nhật địa chỉ cho nhân viên '+ trim(@manv) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Nhân viên '+ trim(@manv) +N' không tồn tại'
	end
end

go

		-- Cập nhật mã người quản lý
create procedure update_nv_manql (@manv char(9),@ma_nql nchar(9))
as
begin
	if(dbo.check_nv(@manv) = 'True' and dbo.check_nql(@ma_nql) = 'True')
	begin try
		update nhanvien
		set ma_nql=@ma_nql
		where manv=@manv
		print N'Cập nhật mã người quản lý cho nhân viên '+ trim(@manv) +N' thành công'
	end try
	begin catch
		print N'Cập nhật mã người quản lý cho nhân viên '+ trim(@manv) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Nhân viên '+ trim(@manv) + N' hoặc người quản lý '+ trim(@ma_nql) +N' không tồn tại'
	end
end

go

	-- Loài
		-- Thêm dữ liệu
create procedure insert_loai (@maloai nchar(9), @tenloai nvarchar(20))
as
begin			
	if(dbo.check_loai(@maloai) = 'True')
	begin
		print N'Loài '+ trim(@maloai) +N' đã tồn tại'
	end
	else
	begin try
		insert into loai(maloai, tenloai)
		values (@maloai, @tenloai)
		print N'Thêm loài '+ trim(@maloai) +N' thành công'
	end try
	begin catch
		print N'Thêm loài '+ trim(@maloai) +N' không thành công. Vui lòng thử lại.'
	end catch
end

go

		-- Xóa loài
create procedure delete_loai (@maloai nchar(9))
as
begin
	if (dbo.check_loai(@maloai) = 'True')
	begin try
		delete from loai
		where loai.maloai = @maloai
		print N'Xóa thành công loài '+ trim(@maloai)
	end try
	begin catch
		print N'Không thể xóa loài '+ trim(@maloai) + N'. (Có dữ liệu thú cưng liên quan đến loài này)'
	end catch
	else
	begin
		print N'Loài '+ trim(@maloai) + N' không tồn tại.'
	end
end

go

	-- Thú cưng
		-- Thêm dữ liệu thú cưng
create procedure insert_tc (@mathu nchar(9), @makh  nchar(9), @madv  nchar(9), @maloai  nchar(9), @manv  nchar(9), @ngaygui datetime, @ngaytra datetime, @sokg decimal(9,2))
as
begin			
	if(dbo.check_tc(@mathu,@ngaygui) = 'True')
	begin
		print N'Thú cưng '+ trim(@mathu) + N' với ngày gửi '+ trim(Convert(nvarchar,@ngaygui, 105)) +N' đã tồn tại'
	end
	else
	begin try
		if(dbo.check_thucung(@makh, @madv, @maloai, @manv) = 'True')
		begin
			insert into thucung(mathu, makh, madv, maloai, manv, ngaygui, ngaytra, sokg)
			values (@mathu, @makh, @madv, @maloai, @manv, @ngaygui, @ngaytra, @sokg)
			print N'Thêm thú cưng '+ trim(@mathu) +N' thành công'
		end
		else
		begin
			print N'Các mã sau đây có thể không tồn tai: mã khách hàng, mã dịch vụ, mã loài, mã nhân viên. Vui lòng kiểm tra.'
		end
	end try
	begin catch
		print N'Thêm thú cưng '+ trim(@mathu) +N' không thành công. Vui lòng thử lại.'
	end catch
end

go

		-- Xóa thú cưng
create procedure delete_tc (@matc nchar(9), @ngaygui datetime)
as
begin
	if (dbo.check_tc(@matc, @ngaygui) = 'True')
	begin
		delete from thucung
		where thucung.mathu = @matc and thucung.ngaygui = @ngaygui
		print N'Xóa thành công thú cưng '+ trim(@matc) + N' có ngày gửi là '+ trim(Convert(nvarchar, @ngaygui, 105))
	end
	else
	begin
		print N'Thú cưng '+ trim(@matc) +N' hoặc ngày '+ trim(Convert(nvarchar, @ngaygui, 105)) + N' không tồn tại.'
	end
end

go

		-- Cập nhật số kí
create procedure update_tc_sokg (@matc nchar(9), @ngaygui datetime, @sokg decimal(9,2))
as
begin
	if(dbo.check_tc(@matc, @ngaygui) = 'True')
	begin try
		update thucung
		set sokg=@sokg
		where mathu=@matc and ngaygui = @ngaygui
		print N'Cập nhật cân nặng cho thú cưng '+ trim(@matc) +N' thành công'
	end try
	begin catch
		print N'Cập nhật cân nặng cho thú cưng '+ trim(@matc) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Thú cưng '+ trim(@matc) + N' không tồn tại hoặc ngày gửi '+ trim(Convert(nvarchar,@ngaygui,105)) +N' không đúng.'
	end
end

go

		-- Cập nhật mã loài
create procedure update_tc_maloai (@matc nchar(9), @ngaygui datetime, @maloai nchar(9))
as
begin
	if (dbo.check_loai(@maloai) = 'True')
	begin
		if(dbo.check_tc(@matc, @ngaygui) = 'True')
		begin try
			update thucung
			set maloai=@maloai
			where mathu=@matc and ngaygui = @ngaygui
			print N'Cập nhật mã loài cho thú cưng '+ trim(@matc) +N' thành công'
		end try
		begin catch
			print N'Cập nhật mã loài cho thú cưng '+ trim(@matc) +N' không thành công. Vui lòng thử lại.'
		end catch
		else
		begin
			print N'Thú cưng '+ trim(@matc) + N' không tồn tại hoặc ngày gửi '+ trim(Convert(nvarchar,@ngaygui,105)) +N' không đúng.'
		end
	end
	else
	begin
		print N'Loài '+ trim(@maloai) +N' không tồn tại'
	end
end

go

		-- Cập nhật mã dịch vụ
create procedure update_tc_madv (@matc nchar(9), @ngaygui datetime, @madv nchar(9))
as
begin
	if (dbo.check_dv(@madv) = 'True')
	begin
		if(dbo.check_tc(@matc, @ngaygui) = 'True')
		begin try
			update thucung
			set madv=@madv
			where mathu=@matc and ngaygui = @ngaygui
			print N'Cập nhật mã dịch vụ cho thú cưng '+ trim(@matc) +N' thành công'
		end try
		begin catch
			print N'Cập nhật mã dịch vụ cho thú cưng '+ trim(@matc) +N' không thành công. Vui lòng thử lại.'
		end catch
		else
		begin
			print N'Thú cưng '+ trim(@matc) + N' không tồn tại hoặc ngày gửi '+ trim(Convert(nvarchar,@ngaygui,105)) +N' không đúng.'
		end
	end
	else
	begin
		print N'Dịch vụ '+ trim(@madv) +N' không tồn tại'
	end
end

go

		-- Cập nhật mã khách hàng
create procedure update_tc_makh (@matc nchar(9), @ngaygui datetime, @makh nchar(9))
as
begin
	if (dbo.check_kh(@makh) = 'True')
	begin
		if(dbo.check_tc(@matc, @ngaygui) = 'True')
		begin try
			update thucung
			set makh=@makh
			where mathu=@matc and ngaygui = @ngaygui
			print N'Cập nhật mã khách hàng cho thú cưng '+ trim(@matc) +N' thành công'
		end try
		begin catch
			print N'Cập nhật mã khách hàng cho thú cưng '+ trim(@matc) +N' không thành công. Vui lòng thử lại.'
		end catch
		else
		begin
			print N'Thú cưng '+ trim(@matc) + N' không tồn tại hoặc ngày gửi '+ trim(Convert(nvarchar,@ngaygui,105)) +N' không đúng.'
		end
	end
	else
	begin
		print N'Khách hàng '+ trim(@makh) +N' không tồn tại'
	end
end

go

		-- Cập nhật mã nhân viên
create procedure update_tc_manv (@matc nchar(9), @ngaygui datetime, @manv nchar(9))
as
begin
	if (dbo.check_nv(@manv) = 'True')
	begin
		if(dbo.check_tc(@matc, @ngaygui) = 'True')
		begin try
			update thucung
			set manv=@manv
			where mathu=@matc and ngaygui = @ngaygui
			print N'Cập nhật mã nhân viên cho thú cưng '+ trim(@matc) +N' thành công'
		end try
		begin catch
			print N'Cập nhật mã nhân viên cho thú cưng '+ trim(@matc) +N' không thành công. Vui lòng thử lại.'
		end catch
		else
		begin
			print N'Thú cưng '+ trim(@matc) + N' không tồn tại hoặc ngày gửi '+ trim(Convert(nvarchar,@ngaygui,105)) +N' không đúng.'
		end
	end
	else
	begin
		print N'Nhân viên '+ trim(@manv) +N' không tồn tại'
	end
end

go

		-- Cập nhật ngày
create procedure update_tc_ngay (@matc nchar(9), @ngaygui datetime, @ngayguimoi datetime,@ngaytra datetime)
as
begin
	if(dbo.check_tc(@matc, @ngaygui) = 'True')
	begin try
		update thucung
		set ngaygui=@ngayguimoi, ngaytra = @ngaytra
		where mathu=@matc and ngaygui = @ngaygui
		print N'Cập nhật ngày gửi và ngày trả cho thú cưng '+ trim(@matc) +N' thành công'
	end try
	begin catch
		print N'Cập nhật ngày gửi và ngày trả cho thú cưng '+ trim(@matc) +N' không thành công. Vui lòng thử lại.'
	end catch
	else
	begin
		print N'Thú cưng '+ trim(@matc) + N' không tồn tại hoặc ngày gửi '+ trim(Convert(nvarchar,@ngaygui,105)) +N' không đúng.'
	end
end

go

-- Tạo các ràng buộc
	--Viết ràng buộc số dt là duy nhất
alter table khachhang   
add constraint duynhat_sdt_khachhang unique (sdt);
alter table nhanvien   
add constraint duynhat_sdt_nhanvien unique (sdt);
	-- Viết ràng buộc số đt phải là 10 chữ số 
alter table khachhang   
add constraint sdt_khachhang_10so check (len(sdt) = 10 and isnumeric(sdt) = 1);
alter table nhanvien   
add constraint sdt_nhanvien_10so check (len(sdt) = 10 and isnumeric(sdt) = 1);

	-- Viết ràng buộc các mã khách hàng, mã nhân viên, mã loài, mã dịch vụ là duy nhất
alter table nhanvien   
add constraint duynhat_ma_nhanvien unique (manv);
alter table khachhang   
add constraint duynhat_ma_khachhang unique (makh);
alter table loai   
add constraint duynhat_ma_loai unique (maloai);
alter table dichvu   
add constraint duynhat_ma_dichvu unique (madv);

	-- Viết ràng buộc giới tính của nhân viên phải là nam hoặc nữ
alter table nhanvien   
add constraint gioitinh_nhanvien check(gioitinh IN (N'Nam',N'Nữ'));	

	-- Viết ràng buộc ngày trả phải sau ngày gửi và không vượt quá 30 ngày
alter table thucung   
add constraint check_ngaygui check (ngaytra - ngaygui <= 30 AND ngaytra - ngaygui >= 0);

	-- Ràng buộc khi thêm một thú cưng phải đảm bảo các makh, madv, maloai, manv phải tồn tại trong các bảng tương ứng
alter table thucung   
add constraint thucung_khoangoai check(dbo.check_thucung(makh, madv, maloai, manv) = 'True');	

go

-- Viết Trigger cho bảng thú cưng
	-- Insert
create trigger trg_insert_tc 
	on thucung
	after insert
as
begin
	update khachhang
	set khachhang.sohd = isnull(khachhang.sohd,0) + 1
	from khachhang
	join inserted on khachhang.makh = inserted.makh
end

go

	-- Delete
create trigger trg_delete_tc
    on thucung
    for delete
as
begin
	update khachhang
	set sohd = isnull(khachhang.sohd,0) - 1
	from khachhang
	join deleted on khachhang.makh = deleted.makh
end

go
	
	-- Update
create trigger trg_update_tc
    on thucung
    after update
as
begin
	update khachhang
	set sohd = isnull(khachhang.sohd,0) - 1
	from khachhang
	join deleted on khachhang.makh = deleted.makh

	update khachhang
	set sohd = isnull(khachhang.sohd,0) + 1
	from khachhang
	join inserted on khachhang.makh = inserted.makh
end

-- Nhập dữ liệu cho các bảng
set dateformat DMY;

-- Bảng nhân viên
exec insert_nv '001',N'Viên',N'Thanh',N'Nhã','01/01/1980',N'Nam',N'Số 548/42, ấp Phước Yên A, Xã Phú Quới, Huyện Long Hồ, Tỉnh Vĩnh Long','0123556789',NULL
exec insert_nv '002',N'Huỳnh',N'Trịnh Tiến',N'Khoa','14/05/2003',N'Nam',N'49 Chung Thành Châu, K4, P5, TP Cà Mau, Tỉnh Cà Mau','0123456789',NULL
exec insert_nv '003',N'Lê',N'Trần Khánh',N'Phú','25/07/2003',N'Nữ',N'21/61 Phan Đăng Lưu,P9,TP Tuy Hòa,Tỉnh Phú Yên','0123756789','001'
exec insert_nv '004',N'Nguyễn',N'Ngọc Tường',N'Vy','23/11/2003',N'Nữ',N'21/61 Phan Đăng Lưu,P9,TP Tuy Hòa,Tỉnh Phú Yên','0123456780','001'
exec insert_nv '005',N'Trương',N'Thanh',N'Phong','07/10/2003',N'Nam',N'246 Nguyễn Trãi, phường An Lạc, Thị Xã Buôn Hồ','0123456781','001'
exec insert_nv '006',N'Huỳnh',N'Nguyễn Anh',N'Cường','24/12/2003',N'Nam',N'76 Huỳnh Thúc Kháng,Dinh Thành 1,Duyên Khánh,Tỉnh Khánh Hòa','0123563247','002'

-- Bảng khách hàng
exec insert_kh 'KH001', N'Ngô Gia Bảo', N'Cần Thơ', '0114477889'
exec insert_kh 'KH002', N'Lý Gia Thuận', N'Trà Vinh', '0116622889'
exec insert_kh 'KH003', N'Huỳnh Trịnh Tiến Vinh', N'Cà Mau', '0114497889'
exec insert_kh 'KH004', N'Trần Quốc Thịnh', N'Cà Mau', '0114477189'
exec insert_kh 'KH005', N'Huỳnh Nguyễn Hoàng Lâm', N'Khánh Hòa', '0223344556'
exec insert_kh 'KH006', N'Đỗ Xuân Phúc', N'Hà Nội', '0113113113'
exec insert_kh 'KH007', N'Vương Đình Huệ', N'Hà Nội', '0112112112'
exec insert_kh 'KH008', N'Joe Biden', N'Hoa Kỳ', '0911911911'
exec insert_kh 'KH009', N'Bùi Phương Linh', N'Hà Nội', '0906120191'
exec insert_kh 'KH010', N'Tập Cận Bình', N'Trung Hoa', '0000000000'

-- Bảng loài
exec insert_loai 'C001', N'Chó Cỏ'
exec insert_loai 'C002', N'Chó Corgi'
exec insert_loai 'C003', N'Chihuahua'
exec insert_loai 'C004', N'Chó Phốc'
exec insert_loai 'C005', N'Alaska'
exec insert_loai 'C006', N'Husky'
exec insert_loai 'C007', N'Pull'
exec insert_loai 'M001', N'Mèo Anh Chân Ngắn'
exec insert_loai 'M002', N'Mèo Ta'
exec insert_loai 'M003', N'Mèo Trụi Lông'
exec insert_loai 'M004', N'Mèo Ai Cập'
exec insert_loai 'M005', N'Mèo Ba Tư'
exec insert_loai 'M006', N'Mèo Mướp'
exec insert_loai 'T001', N'Thỏ Bảy màu'

-- Bảng dịch vụ
exec insert_dv 'CL', N'Cạo Lông', '250000'
exec insert_dv 'TL', N'Tỉa Lông', '250000'
exec insert_dv 'NL', N'Nhuộm Lông', '300000'
exec insert_dv 'TR', N'Tắm Rửa', '200000'
exec insert_dv 'SP', N'Spa', '300000'
exec insert_dv 'TG', N'Trông Giữ', '100000'
exec insert_dv 'ECB', N'Eco Combo (Cạo/Tỉa Tắm)', '400000'
exec insert_dv 'SCB', N'Special Combo (Cạo/Tỉa + Tắm + Spa + TG )', '800000'
exec insert_dv 'SSCB', N'Super Special Combo (Cạo/Tỉa + Nhuộm + Spa + TG )', '850000'

-- Bảng thú cưng
exec insert_tc 'TC001', 'KH001', 'ECB', 'C001', '001', '1/1/2022', '1/1/2022', '2'
exec insert_tc 'TC001', 'KH001', 'TR', 'C001', '002', '2/2/2022', '2/2/2022', '2.2'

exec insert_tc 'TC002', 'KH002', 'SP', 'C002', '002', '3/1/2022', '3/1/2022', '3'
exec insert_tc 'TC002', 'KH002', 'SP', 'C002', '006', '3/2/2022', '3/2/2022', '3'
exec insert_tc 'TC002', 'KH002', 'SP', 'C002', '002', '6/3/2022', '6/3/2022', '3'

exec insert_tc 'TC003', 'KH002', 'SSCB', 'C002', '003', '3/1/2022', '6/1/2022', '4'
exec insert_tc 'TC003', 'KH002', 'NL', 'C002', '004', '3/5/2022', '3/5/2022', '4'

exec insert_tc 'TC004', 'KH003', 'TR', 'M004', '004', '4/1/2022', '4/1/2022', '3'
exec insert_tc 'TC004', 'KH003', 'SP', 'M004', '003', '1/2/2022', '1/2/2022', '4'
exec insert_tc 'TC004', 'KH003', 'SCB', 'M004', '005', '2/2/2022', '26/2/2022', '4'
exec insert_tc 'TC004', 'KH003', 'SCB', 'M004', '006', '1/6/2022', '26/6/2022', '3'

exec insert_tc 'TC005', 'KH003', 'ECB', 'M005', '001', '4/1/2022', '4/1/2022', '3.6'
exec insert_tc 'TC005', 'KH003', 'SSCB', 'M005', '005', '4/5/2022', '24/5/2022', '3.6'

exec insert_tc 'TC006', 'KH004', 'SCB', 'M001', '002', '5/1/2022', '10/1/2022', '5'
exec insert_tc 'TC006', 'KH004', 'CL', 'M001', '003', '10/4/2022', '10/4/2022', '5'

exec insert_tc 'TC007', 'KH005', 'NL', 'C004', '004', '25/4/2022', '25/4/2022', '1.5'
exec insert_tc 'TC007', 'KH005', 'SCB', 'C004', '006', '12/5/2022', '25/5/2022', '1.5'

exec insert_tc 'TC008', 'KH001', 'SSCB', 'M006', '002', '22/2/2022', '25/2/2022', '3.4'
exec insert_tc 'TC008', 'KH001', 'TG', 'M006', '005', '22/3/2022', '22/3/2022', '3.4'

exec insert_tc 'TC009', 'KH006', 'SSCB', 'M002', '001', '2/1/2022', '15/1/2022', '4'
exec insert_tc 'TC009', 'KH006', 'SSCB', 'M002', '006', '2/2/2022', '25/2/2022', '4'
exec insert_tc 'TC009', 'KH006', 'SSCB', 'M002', '005', '2/3/2022', '5/3/2022', '4'
exec insert_tc 'TC009', 'KH006', 'SSCB', 'M002', '003', '12/4/2022', '20/4/2022', '4'
exec insert_tc 'TC009', 'KH006', 'SSCB', 'M002', '004', '1/5/2022', '5/5/2022', '4'
exec insert_tc 'TC009', 'KH006', 'SSCB', 'M002', '002', '20/6/2022', '28/6/2022', '4'

exec insert_tc 'TC010', 'KH007', 'SP', 'C006', '001', '5/2/2022', '5/2/2022', '2'
exec insert_tc 'TC010', 'KH007', 'SSCB', 'C006', '006', '7/5/2022', '15/5/2022', '2'

exec insert_tc 'TC011', 'KH007', 'TL', 'M001', '003', '22/6/2022', '22/6/2022', '1.6'

exec insert_tc 'TC012', 'KH008', 'SSCB', 'C002', '004', '2/4/2022', '5/4/2022', '10'

exec insert_tc 'TC013', 'KH009', 'SSCB', 'T001', '002', '19/3/2022', '12/4/2022', '5.8'
exec insert_tc 'TC013', 'KH009', 'SSCB', 'T001', '002', '14/5/2022', '12/6/2022', '5.8'

exec insert_tc 'TC014', 'KH010', 'CL', 'M001', '003', '22/1/2022', '22/1/2022', '2.4'

exec insert_tc 'TC015', 'KH010', 'SSCB', 'C007', '006', '22/1/2022', '5/2/2022', '1.2'
exec insert_tc 'TC015', 'KH010', 'TR', 'C007', '005', '2/3/2022', '2/3/2022', '1.2'


-- Truy vấn dữ liệu
-- Truy vấn một bảng
	-- Truy vấn bảng dich vụ
select madv N'Mã Dịch Vụ', tendv N'Tên Dịch Vụ', giatien N'Giá Tiền'
from dichvu

	-- Truy vấn bảng loài
select maloai N'Mã Loài', tenloai N'Tên Loài'
from loai

	-- Truy vấn bảng nhân viên
select manv N'Mã Nhân Viên', honv + ' ' + tenlot + ' ' + tennv N'Tên Nhân Viên', Convert(varchar,ngaysinh,105) N'Ngày Sinh', gioitinh N'Giới Tính', diachi N'Địa Chỉ', sdt N'Số ĐT', ma_nql N'Mã Người Quản Lý'
from nhanvien

	-- Truy vấn bảng khách hàng
select makh N'Mã Khách Hàng', tenkh N'Tên Khách Hàng', diachi N'Đia Chỉ', sdt N'Số ĐT', sohd N'Số hóa đơn'
from khachhang

	-- Truy vấn bảng thú cưng
select mathu N'Mã Thú', kh.tenkh N'Khách Hàng', l.tenloai N'Loài', tc.sokg N'Cân nặng',dv.tendv N'Dịch Vụ', nv.honv + ' ' + nv.tenlot + ' ' + nv.tennv N'Nhân Viên', Convert(varchar,tc.ngaygui,105) N'Ngày gửi', Convert(varchar,tc.ngaytra,105) N'Ngày trả'
from thucung tc, khachhang kh, nhanvien nv, loai l, dichvu dv
where (tc.makh = kh.makh AND tc.maloai = l.maloai AND tc.manv = nv.manv AND tc.madv = dv.madv)

	-- Truy vấn bảng hóa đơn
select hd.mahd, kh.tenkh N'Khách Hàng', dv.tendv N'Tên Dịch Vụ', nv.honv + ' ' + nv.tenlot + ' ' + nv.tennv N'Nhân Viên', hd.sokg N'Cân nặng', Convert(varchar,hd.ngaygui,105) N'Ngày gửi', Convert(varchar,hd.ngaytra,105) N'Ngày trả', hd.tongtien N'Tổng Tiền'
from dbo.tHoadon() hd, khachhang kh, dichvu dv, nhanvien nv
where (hd.makh = kh.makh and hd.madv = dv.madv and hd.manv = nv.manv)

	-- Truy vấn bảng lương của toàn bộ nhân viên trong tháng 1 năm 2022 với lương cứng là 4 triệu
select * from dbo.tBangluong(1,2022, 2000000)
select * from dbo.tBangluong(2,2022, 2000000)
select * from dbo.tBangluong(3,2022, 2000000)
select * from dbo.tBangluong(4,2022, 2000000)
select * from dbo.tBangluong(5,2022, 2000000)
select * from dbo.tBangluong(6,2022, 2000000)

	-- Truy vấn nhiều bảng (Phép kết)
		-- Sử dụng phép kết hợp (full outer join) 2 bảng khách hàng và nhân viên, để truy vấn bảng các nhân viên có khả năng phục vụ cho mỗi khách hàng có quản lý là '001' gồm (mã khách hàng, mã nhân viên)
select kh.makh N'Mã Khách Hàng', nv.manv N'Mã Nhân Viên'
from khachhang kh full outer join nhanvien nv
on nv.ma_nql = 1

		-- Sử dụng phép kết hợp (inner join) 2 bảng nhân viên và thú cưng, để truy vấn bảng thông tin thú cưng và nhân viên thực hiện dich vụ gồm (mã nhân viên, tên nhân viên, mã thú, ngày gửi, mã dịch vụ)
select nv.manv N'Mã Nhân Viên', nv.honv + ' ' + nv.tenlot + ' ' + nv.tennv N'Tên Nhân Viên',tc.mathu N'Mã Thú Cưng', Convert(nvarchar, tc.ngaygui, 105) N'Ngày gửi', tc.madv N'Mã Dịch Vụ'
from nhanvien nv inner join thucung tc
on nv.manv = tc.manv

		-- Sử dụng phép kết hợp (left join) 2 bảng loài và thú cưng, để truy vấn bảng thú cưng của từng loài nếu loài không có thú cưng nào thì hiện Null gồm (mã loài, tên loài, mã thú cưng)
select distinct l.maloai N'Mã Loài', l.tenloai N'Tên Loài', tc.mathu N'Mã Thú'
from loai l left join thucung tc
on l.maloai = tc.maloai

		-- Sử dụng phép kết hợp (right join) 2 bảng khách hàng và hóa đơn, để truy vấn bảng khách hàng phải thanh toán tiền cho mỗi hóa đơn gồm (mã khách hàng, tên khách hàng, mã hóa đơn, tên hóa đơn)
select kh.makh N'Mã Khách Hàng', kh.tenkh N'Tên Khách Hàng', hd.mahd N'Mã Hóa Đơn', hd.tongtien N'Tổng Tiền Phải Thanh Toán'
from khachhang kh right join dbo.tHoadon() hd
on kh.makh = hd.makh

	-- Truy vấn có điều kiện (and, or, like, between, ...)
		-- Sử dụng điều kiện and, để truy vấn bảng các hóa đơn trong tháng 1 sử dụng dịch vụ ECB gồm (mã hóa đơn, mã khách hàng, tổng tiền)
select hd.mahd N'Mã Hóa Đơn', hd.makh N'Mã Khách Hàng',hd.tongtien N'Tổng Tiền'
from dbo.tHoadon() hd
where month(hd.ngaygui) = 1 and hd.madv = 'ECB'

		-- Sử dụng điều kiện or, để truy vấn bảng các hóa đơn trong tháng 1 sử dụng dịch vụ SSCB hoặc có tổng tiền lớn hơn 500000 (mã hóa đơn, mã khách hàng, mã dịch vụ,tổng tiền)
select hd.mahd N'Mã Hóa Đơn', hd.madv N'Mã Dịch Vụ',hd.makh N'Mã Khách Hàng',hd.tongtien N'Tổng Tiền'
from dbo.tHoadon() hd
where month(hd.ngaygui) = 1 and (hd.madv = 'SSCB' or hd.tongtien > 500000)

		-- Sử dụng điều kiện like, để truy vấn bảng các khách hàng có họ Huỳnh để tặng gói dịch vụ ECB (mã khách hàng, tên khách hàng, quà tặng)
select kh.makh N'Mã Khách Hàng', kh.tenkh N'Tên Khách Hàng',N'ECB' N'Quà Tặng'
from khachhang kh
where kh.tenkh like N'Huỳnh%'

		-- Sử dụng điều kiện between, để truy vấn bảng các thú cưng có số kí từ 2 đến 5 (mã thú, số kí)
select distinct tc.mathu N'Mã Thú', tc.sokg N'Số Kí'
from thucung tc
where tc.sokg between 2 and 5

	-- Truy vấn tính toán
		-- Truy vấn bảng khách hàng có từ 2 hóa đơn trở lên để giảm giá cho dịch vụ tiếp theo (mã khách hàng, tên khách hàng, giảm giá)
select kh.makh N'Mã Khách Hàng', kh.tenkh N'Tên Khách Hàng', Convert(nvarchar,kh.sohd*10) + N'%' N'Giảm Giá'
from khachhang kh
where kh.sohd >= 2

		-- Truy vấn bảng 3 thú cưng có số cân nặng lớn nhất để giảm giá cho dich vụ tiếp theo (mã thú cưng, mã khách hàng, giảm giá)
select top(3) tc.mathu N'Mã Thú', tc.makh 'Mã Khách Hàng', tc.gg + N'%' N'Giảm Giá'
from (
select distinct mathu , makh ,Convert(nvarchar,sokg*5) gg, sokg
from thucung
) tc
order by tc.sokg desc

		-- Truy vấn bảng các nhân viên có tiền công lớn hơn lương cứng / 10 trong tháng 1 để thưởng 1/2 số tiền công (Mã nhân viên, tiền công, tiền thưởng)
select bl.[Mã nhân viên], bl.[Tiền công theo hóa đơn (15%)], bl.[Tiền công theo hóa đơn (15%)] / 2 N'Tiền Thưởng'
from dbo.tBangluong(1,2022, 2000000) bl
where bl.[Tiền công theo hóa đơn (15%)] > bl.[Lương cứng] / 10

		-- Truy vấn bảng các hóa đơn trong tháng 1 để hoàn lại 10% tiền tổng hóa đơn (mã hóa đơn, mã khách hàng, tiền trả)
select mahd N'Mã Hóa Đơn', makh N'Mã Khách Hàng',Convert(int, tongtien/10) N'Tiền trả'
from dbo.tHoadon() 
where month(ngaygui) = 1 and madv = 'SSCB'

	-- Truy vấn gom nhóm (group by)
		-- Truy vấn bảng số đơn đã thực hiện trong tháng 1 của mỗi nhân viên (mã nhân viên, số đơn đã thực hiện)
select nv.manv N'Mã Nhân Viên', count(tc.mathu) N'Số Đơn Đã Thực Hiện'
from nhanvien nv left join thucung tc
on nv.manv = tc.manv and month(tc.ngaygui) = 1
group by nv.manv

		-- Truy vấn số lần sử dụng dịch vụ trong tháng 1 của mỗi thú cưng (mã thú, số dịch vụ)
select tc.mathu N'Mã Thú', count(tc.madv) N'Số dịch vụ'
from thucung tc
where month(tc.ngaygui) = 1
group by tc.mathu

		-- Truy vấn số lần thực hiện của mỗi dịch vụ trong tháng 1 (mã dịch vụ, số đơn)
select dv.madv N'Mã Dịch Vụ', count(tc.madv) N'Số Đơn'
from dichvu dv left join thucung tc
on month(tc.ngaygui) = 1 and dv.madv = tc.madv
group by dv.madv
order by count(tc.madv) desc

		-- Truy vấn số dịch vụ mà 1 khách hàng sử dụng trong tháng 1 (mã khách hàng, số dịch vụ)
select kh.makh N'Mã Dịch Vụ', count(tc.madv) N'Số Đơn'
from khachhang kh left join thucung tc
on month(tc.ngaygui) = 1 and kh.makh = tc.makh
group by kh.makh
order by count(tc.madv) desc

	-- Truy vấn gom nhóm có điều kiện (having)
		-- Truy vấn bảng các nhân viên thưc hiện số đơn làm việc trong tháng 1 (điều kiện: nhiều hơn 2) (mã nhân viên, số đơn đã thực hiện)
select nv.manv N'Mã Nhân Viên', count(tc.mathu) N'Số Đơn Đã Thực Hiện'
from nhanvien nv left join thucung tc
on nv.manv = tc.manv and month(tc.ngaygui) = 1
group by nv.manv
having count(tc.mathu) >= 2

		-- Truy vấn số lần sử dụng dịch vụ trong tháng 2 của mỗi thú cưng (điều kiện: nhiều hơn 2) (mã thú, số dịch vụ)
select tc.mathu N'Mã Thú', count(tc.madv) N'Số dịch vụ'
from thucung tc
where month(tc.ngaygui) = 2
group by tc.mathu
having count(tc.madv) >= 2

		-- Truy vấn số lần thực hiện của mỗi dịch vụ trong tháng 1 (điều kiện: nhiều hơn 2) (mã dịch vụ, số đơn)
select dv.madv N'Mã Dịch Vụ', count(tc.madv) N'Số Đơn'
from dichvu dv left join thucung tc
on month(tc.ngaygui) = 1 and dv.madv = tc.madv
group by dv.madv
having count(tc.madv) >= 2
order by count(tc.madv) desc

		-- Truy vấn số dịch vụ mà 1 khách hàng sử dụng trong tháng 1 (điều kiện: nhiều hơn 2) (mã khách hàng, số dịch vụ)
select kh.makh N'Mã Dịch Vụ', count(tc.madv) N'Số Đơn'
from khachhang kh left join thucung tc
on month(tc.ngaygui) = 1 and kh.makh = tc.makh
group by kh.makh
having count(tc.madv) >= 2
order by count(tc.madv) desc
	
	-- Truy vấn có sử dụng phép giao, hội, trừ
		-- Sử dụng phép giao để truy vấn những nhân viên đã làm việc trong tháng 6 (mã nhân viên, tên nhân viên)
select manv N'Mã Nhân Viên', honv + ' ' + tenlot + ' ' + tennv N'Tên Nhân Viên'
from nhanvien
where manv in (
select manv from nhanvien
intersect
select manv from thucung where month(ngaygui) = 6
)

		-- Sử dụng phép hợp để truy vấn những thú cưng được chăm sóc bởi những nhân viên có quản lý là Null và 001 trong tháng 1 (mã nhân viên, mã thú)
select manv, mathu
from thucung
where manv in (
select manv from nhanvien where ISNULL(ma_nql, 0) = 0
union
select manv from nhanvien where ma_nql = 1
) and month(ngaygui) = 1

		-- Sử dụng phép trừ để truy vấn những nhân viên chưa làm việc trong tháng 6 (mã nhân viên, tên nhân viên)
select manv N'Mã Nhân Viên', honv + ' ' + tenlot + ' ' + tennv N'Tên Nhân Viên'
from nhanvien
where manv in (
select manv from nhanvien
except
select manv from thucung where month(ngaygui) = 6
)

		-- Sử dụng phép trừ để truy vấn những khách hàng chưa sử dụng dịch vụ trong tháng 2 (mã khách hàng, tên khách hàng)
select makh N'Mã Khách Hàng', tenkh N'Tên Khách Hàng'
from khachhang
where makh in (
select makh from khachhang
except
select makh from thucung where month(ngaygui) = 2
)

	-- Truy vấn con
		-- Truy vấn số thú cưng của mỗi loài trong tháng 1 (mã loài, mã thú)
select l.maloai N'Mã Loài', count(tc.mathu) N'Mã Thú Cưng'
from loai l left join (
select distinct mathu, maloai 
from thucung 
where  month(ngaygui) = 1
) tc
on l.maloai = tc.maloai
group by l.maloai
order by count(tc.mathu) desc

		-- Truy vấn những thú cưng có chủ ở Cà Mau (mã thú, mã khách hàng)
select distinct mathu N'Mã Thú', makh N'Mã Khách Hàng'
from thucung 
where makh in (
select makh from khachhang
where diachi = N'Cà Mau'
)

		-- Truy vấn những khách hàng ở Cà Mau đã sử dụng dịch vụ trong tháng 2 (mã khách hàng, tên khách hàng)
select makh N'Mã Khách Hàng', tenkh N'Tên Khách Hàng'
from khachhang
where makh in (
select makh from dbo.tHoadon()
where month(Convert(datetime,ngaygui,105)) = 2
) and makh in (
select makh from khachhang
where diachi = N'Cà Mau'
)

		-- Truy vấn những nhân viên ở Phú Yên đã thực hiện dịch vụ trong tháng 2 (mã nhân viên, tên nhân viên)
select manv N'Mã Nhân Viên', honv + ' ' + tenlot + ' ' + tennv N'Tên Nhân Viên'
from nhanvien
where manv in (
select manv from dbo.tHoadon()
where month(Convert(datetime,ngaygui,105)) = 2
) and manv in (
select manv from nhanvien
where diachi like N'%Phú Yên%'
)

	-- Truy vấn chéo (pivot)
		-- Sử dụng truy vấn chéo để tạo một bảng chứa tổng tiền đã chi của các khách hàng có mã là [KH001], [KH002], [KH003]
select N'Tổng Tiền' N'Tổng Các Khoản Chi', [KH001], [KH002], [KH003]
from
( 
select makh, tongtien from dbo.tHoadon() 
where month(Convert(datetime,ngaygui,105)) = 1
) as BangNguon
pivot
(
sum(tongtien) 
for makh in ([KH001], [KH002], [KH003])
) as BangChuyen

		-- Sử dụng truy vấn chéo để tạo một bảng chứa số lần sử dụng dịch vụ của các khách hàng [KH001], [KH002], [KH003] trong tháng 1
select N'Số dịch vụ' N'Khách Hàng', [KH001], [KH002], [KH003]
from
(
select makh from thucung
where month(ngaygui) = 1
) as BangNguon
pivot
(
count(makh)
for makh in ([KH001], [KH002], [KH003])
) as BangChuyen

		-- Sử dụng truy vấn chéo để tạo một bảng chứa số lần sử dụng dịch vụ của các thú cưng [TC001], [TC002], [TC003] trong tháng 1
select N'Số dịch vụ' N'Thú Cưng', [TC001], [TC002], [TC003]
from
(
select mathu from thucung
where month(ngaygui) = 1
) as BangNguon
pivot
(
count(mathu)
for mathu in ([TC001], [TC002], [TC003])
) as BangChuyen

		-- Sử dụng truy vấn chéo để tạo một bảng chứa số dịch vụ mà các nhân viên [001], [002], [003] thưc hiện trong tháng 1
select N'Số dịch vụ' N'Nhân Viên', [001], [002], [003]
from
(
select manv from thucung
where month(ngaygui) = 1
) as BangNguon
pivot
(
count(manv)
for manv in ([001], [002], [003])
) as BangChuyen


-- Phân quyền
-- Tạo tài khoản quản lý
create login nhavt with password = '001'
create login khoahht with password = '002'

-- Phân quyền cho cấp quản lý
create user nvqlycapcao for login nhavt
grant all to nvqlycapcao with grant option
-- Tạo tài khoản nhân viên

-- Phân quyền nhân viên
create user nv_ql for login khoahht
grant select, insert, update, delete on khachhang to nv_ql
grant select, insert, update, delete on thucung to nv_ql

create login phultk with password = '003'
create login vyntt with password = '004'
create login phongtt with password = '005'
create login cuonghna with password = '006'
create user nv3 for login phultk
create user nv4 for login vyntt
create user nv5 for login phongtt
create user nv6 for login cuonghna

grant select, insert on khachhang to nv3
grant select, insert on thucung to nv3
grant select, insert on khachhang to nv4
grant select, insert on thucung to nv4
grant select, insert on khachhang to nv5
grant select, insert on thucung to nv5
grant select, insert on khachhang to nv6
grant select, insert on thucung to nv6
go

-- Thu hồi quyền
revoke select, insert on nv5 from khachhang
revoke select, insert on nv5 from thucung

-- Sao lưu
-- Sao lưu bằng lệnh
create procedure backupdata(@tencsdl nvarchar(99),@tentaptin nvarchar(99))
as
begin
	backup database @tencsdl to disk =@tentaptin
end

exec backupdata 'backupqlythucung','D:\Cơ sở dữ liệu\test final\backupqlythucung.bak'
go
-- Khôi phục dữ liệu bằng SQL
create procedure restoredata(@tencsdl nvarchar(99),@tentaptin nvarchar(99))
as
begin
	restore database @tencsdl from disk = @tentaptin
end
exec restoredata 'backupqlythucung','D:\Cơ sở dữ liệu\test final\backupqlythucung.bak'
go
